// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ERC20Interface {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns(uint balance);
    function allowance(address owner, address spender) external view returns (uint remaining);
    function transfer(address recipient, uint amount) external returns (bool success);
    function approve(address spender, uint amount) external returns (bool success);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

contract gNaira is ERC20Interface {
    string public symbol;
    string public name;
    uint8 public decimals;
    uint public _totalSupply;

    address governor;
    address payable  multiSigAddress;

    mapping(address => uint) balances;
    mapping(address => mapping(address =>uint)) allowed;
    mapping(address =>bool) public  isBlacklisted;

    modifier isGovernor() {
        require(msg.sender == governor, "account is not governor");
        _;
    }

    modifier isMultiSigContract() {
        require(msg.sender == multiSigAddress, "caller is not multiSig");
        _;
    }

    constructor() {
        symbol = "gNGN";
        name = "gNaira";
        decimals = 18;
        _totalSupply = 1_000_000_000_000_000_000_000_000; //initial supply set to 1 million tokens
        governor = msg.sender;                            //the deployer is the governor
        balances[governor] = _totalSupply;
        emit Transfer(address(0), governor, _totalSupply);

    }

    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint balance) {
        return balances[account];
    }

    function transfer(address recipient, uint amount) public returns (bool success) {
        //ensures sender has sufficient balance
        require(amount <= balances[msg.sender], "insufficient balance");
        //ensures sender is not blacklisted
        require(!isBlacklisted[msg.sender], "user is blacklisted and cannot send tokens");
        //ensures receiver is not blacklisted
        require(!isBlacklisted[recipient], "recipient is blacklisted and cannot receive tokens");
        //checks that receiving address is not address(0)
        require(recipient != address(0), "Cannot transfer to zero address");
        balances[msg.sender] = balances[msg.sender] - amount;
        balances[recipient] = balances[recipient] + amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint amount) public returns (bool success) {
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint amount) public returns (bool success) {
        //ensures sender has sufficient balance
        require(amount <= balances[sender], "insufficient sender balance");
        require(!isBlacklisted[sender], "sender is blacklisted and cannot send tokens");
        require(!isBlacklisted[recipient], "recipient is blacklisted and cannot receive tokens");
        //checks that receiving address is not address(0)
        require(recipient != address(0), "Cannot transfer to zero address");
        balances[sender] = balances[sender] - amount;
        allowed[sender][msg.sender] = allowed[sender][msg.sender] - amount;
        balances[recipient] = balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint remaining) {
        return allowed[owner][spender];
    }


    //this function can only be called by current governor to set a new governor
    function setGovernor(address _governor) external isGovernor() {
        governor = _governor;
    }

    /*this function is called to mint new tokens and can only be called through multisig after
    governor mint proposal has been approved */
    function mintTokens(uint amount) external isMultiSigContract() {
        //adds(mints) the amount to the total supply
        _totalSupply = _totalSupply + amount;
        balances[governor] = balances[governor] + amount;      
    }

    /*this is only called by current governor address to submit new mint proposal which will
    be sent to multisig for approval*/
    function submitMint(uint amount) external isGovernor() {
        MultiSig mSig = MultiSig(multiSigAddress);
        mSig.submit(true, amount);

    }
 
    //this is called after deployment to set the contract address of the multisig wallet;
    function setMultiSigAddress(address payable _mSigAddress) public {
        multiSigAddress = _mSigAddress;
    }

    /*this function is called to burn tokens and can only be called through multisig after
    a burn proposal has been approved */
    function burnTokens(uint amount) external isMultiSigContract {
        //subtratcs(burns) the amount from the total supply
        _totalSupply = _totalSupply - amount;
        balances[governor] = balances[governor] - amount;
    }

    /*this is only called by current governor address to submit new burn proposal which will
    be sent to multisig for approval*/
    function submitBurn(uint amount) external isGovernor() {
        MultiSig mSig = MultiSig(multiSigAddress);
        mSig.submit(false, amount);

    }

    //only governor can call this function to blacklist an address
    function blacklistUser(address user) external isGovernor() {
        require(!isBlacklisted[user], "user is already blacklisted");
        isBlacklisted[user] = true;
    }

    //only governor can call this function to remove blacklist for an address
    function removeBlacklist(address user) external isGovernor() {
        require(isBlacklisted[user], "user is not blacklisted");
        isBlacklisted[user] = false;
    }

    function getGovernor() public view returns (address) {
        return governor;      //returns current governor
    }
}

contract MultiSig {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txID);
    event Approve(address indexed admin, uint indexed txID);
    event Revoke(address indexed admin, uint indexed txID);
    event Execute(uint indexed txID);

    struct Proposal {
        bool method;       // true is mint proposal, false is burn proposal
        uint value;
        bool executed;
    }

    address gNairaContractAddress;

    address[] public admins;
    mapping(address => bool) public isAdmin;
    uint public required;

    Proposal[] public proposals;
    mapping(uint => mapping(address => bool)) public approved;

    //this modifier checks is caller is a multiSig admin
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "sender is not an admin");
        _;
    }

    //this modifier checks if a proposal exists
    modifier pplExists(uint _pplID) {
        require(_pplID < proposals.length, "proposal does not exist");
        _;
    } 

    //this modifier checks that a proposal is not approved yet
    modifier notApproved(uint _pplID) {
        require(!approved[_pplID][msg.sender], "proposal already approved");
        _;
    }

    //this modifier checks if a mint/burn proposal has not been executed
    modifier notExecuted(uint _pplID) {
        require(!proposals[_pplID].executed, "proposal already executed");
        _;
    }

    //this modifier ensures caller is gNairaContract
    modifier onlygNairaContract() {
        require(msg.sender == gNairaContractAddress);
        _;
    }

    /* upon deployment, an array of admins must be initialized and the required amount of
    signatures for proposals must be initailized. */
    constructor(address[] memory _admins, uint _required) {
        //checks that deployer set one or more addresses as admin
        require(_admins.length > 0, "at least one admin required");
        //checks that required set by admin is greater than one and less or equal to the number of admins
        require(_required > 0 && _required <= _admins.length, "invalid required");

        /*this loops through the admin array inputed by deployer and updates the local 'admin' 
        array with all address and also updates the isAdmin mapping for each admin*/
        for (uint i = 0; i < _admins.length; i++) {
            require(_admins[i] != address(0), "invalid adrress");
            require(!isAdmin[_admins[i]], "admin already exists");
            admins.push(_admins[i]);
            isAdmin[_admins[i]] = true;
        }

        required = _required;
    
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    //this function is called after deployment to set the gNairaContract address for interaction
    function setgNairaContractAddress(address _gNairaContract) public {
        gNairaContractAddress = _gNairaContract;
    }

    /*this method can only be called by the gNairaContract when the governor wants to mint or burn.
    this method is used to submit a mint or burn proposal for approval by multiSig admins*/
    function submit(bool _method, uint _value) external onlygNairaContract {
        Proposal memory newProposal = Proposal(_method, _value, false);
        proposals.push(newProposal);
        
        emit Submit(proposals.length - 1);
    }

    /*this function is called by admins to approve proposals
    */
    function adminTxApprove(uint _pplID) 
    external onlyAdmin pplExists(_pplID) notApproved(_pplID) notExecuted(_pplID) {
        approved[_pplID][msg.sender] = true;
        emit Approve(msg.sender, _pplID);
    }

    //returns the approval count per proposal
    function getApprovalCount(uint _pplID) public view returns (uint count) {
        //this loops through all admins in the 'admin array' and checks for approval for a proposal 
        for (uint i; i < admins.length; i++) {
            if(approved[_pplID][msg.sender]) {
                count += 1;
            }
        }

    }

    /*this function is called when a proposal is to be executed. the proposal must have
    the minimum amount of required approvals to be executed*/
    function execute(uint _pplID) external pplExists(_pplID) notExecuted(_pplID) {  //isGovernor?
        require(getApprovalCount(_pplID) >= required, "not enough approvals");
        Proposal storage proposal = proposals[_pplID];
        proposal.executed = true;

        //check if the gNaira contract address has been set and creates an instance for it to use for interaction
        require(gNairaContractAddress != address(0), "gNaira address has not been initialized");
        gNaira g_naira = gNaira(gNairaContractAddress);

        if(proposal.method) {                   //true value = mint
            
            g_naira.mintTokens(proposal.value);

        } else if(!proposal.method) {           //false value = burn
            g_naira.burnTokens(proposal.value);
        }
        
        emit Execute(_pplID);
    }

    // this function is used to revoke approval for a proposal by an admin
    function revoke(uint _pplID) external onlyAdmin pplExists(_pplID) notExecuted(_pplID) {
        require(approved[_pplID][msg.sender], "transaction not approved");
        approved[_pplID][msg.sender] = false;
        emit Revoke(msg.sender, _pplID);
    } 
}