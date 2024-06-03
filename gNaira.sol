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
    address selfContract;

    bytes data;

    mapping(address => uint) balances;
    mapping(address => mapping(address =>uint)) allowed;
    mapping(address =>bool) public  isBlacklisted;

    modifier isGovernor() {
        require(msg.sender == governor, "account is not governor");
        _;
    }

    constructor() {
        symbol = "tNGN";
        name = "testNaira";
        decimals = 18;
        _totalSupply = 1_000_000_000_000_000_000_000_000; //initial supply set to 1 million tokens
        governor = msg.sender;
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
        require(amount <= balances[msg.sender], "insufficient balance");
        require(!isBlacklisted[msg.sender], "user is blacklisted and cannot send tokens");
        require(!isBlacklisted[recipient], "recipient is blacklisted and cannot receive tokens");
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
        balances[sender] = balances[sender] - amount;
        allowed[sender][msg.sender] = allowed[sender][msg.sender] - amount;
        balances[recipient] = balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint remaining) {
        return allowed[owner][spender];
    }

    function mintTokens(uint amount, address minter) public  {
        _totalSupply = _totalSupply + amount;
        balances[minter] = balances[minter] + amount;
        //return true;

    }

    function submitMint(uint amount) external isGovernor() {
        MultiSig mSig = MultiSig(multiSigAddress);
        mSig.submit(true, amount, msg.sender);

        // _totalSupply = _totalSupply + amount;
        // balances[minter] = balances[minter] + amount;
        // //return true;

    }
 
    function setMultiSigAddress(address payable _mSigAddress) public {
        multiSigAddress = _mSigAddress;
    }

    function burnTokens(uint amount) external isGovernor() {
        
        _totalSupply = _totalSupply - amount;
        balances[governor] = balances[governor] - amount;
        //return true;
    }

    function burnTokensFrom(address to, uint amount) external isGovernor() {
        _totalSupply = _totalSupply - amount;
        balances[to] = balances[to] - amount;
        //return true;
    }

    function blacklistUser(address user) external isGovernor() {
        require(!isBlacklisted[user], "user is already blacklisted");
        isBlacklisted[user] = true;
    }

    function removeBlacklist(address user) external isGovernor() {
        require(isBlacklisted[user], "user is not blacklisted");
        isBlacklisted[user] = false;
    }

    function getGovernor() public view returns (address) {
        return governor;
    }
}

contract MultiSig {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txID);
    event Approve(address indexed admin, uint indexed txID);
    event Revoke(address indexed admin, uint indexed txID);
    event Execute(uint indexed txID);

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    struct Proposal {
        address user;
        bool method;       // true is mint, false is burn
        uint value;
        bool executed;
    }

    address gNairaContractAddress;

    address[] public admins;
    mapping(address => bool) public isAdmin;
    uint public required;

    Proposal[] public proposals;
    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "sender is not an admin");
        _;
    }

    // modifier txExists(uint _txID) {
    //     require(_txID < transactions.length, "transaction does not exist");
    //     _;
    // } 

    modifier txExists(uint _txID) {
        require(_txID < proposals.length, "transaction does not exist");
        _;
    } 

    modifier notApproved(uint _txID) {
        require(!approved[_txID][msg.sender], "transaction already approved");
        _;
    }

    // modifier notExecuted(uint _txID) {
    //     require(!transactions[_txID].executed, "transaction already executed");
    //     _;
    // }

    modifier notExecuted(uint _txID) {
        require(!proposals[_txID].executed, "transaction already executed");
        _;
    }

//["0x634bC37172eCDD1Eb18Fb1C1f1E043006be5Cc60", "0x66D39d6dbA140b341e8B9e32f43042229ae66517"]
    constructor(address[] memory _admins, uint _required) {
        require(_admins.length > 0, "at least two admins required");
        require(_required > 0 && _required <= _admins.length, "invali required");

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

    // function submit(address _to, uint _value, bytes calldata _data) public {
    //     transactions.push(Transaction({
    //         to: _to,
    //         value: _value,
    //         data: _data,
    //         executed: false
    //     }));
    //     emit Submit(transactions.length - 1);
    // }

    function setgNairaContractAddress(address _gNairaContract) public {
        gNairaContractAddress = _gNairaContract;
    }

    function submit(bool _method, uint _value, address _minter) public {
        Proposal memory newProposal = Proposal(_minter, _method, _value, false);
        proposals.push(newProposal);
        
        //emit Submit(transactions.length - 1);
    }

    function multisigApprove(uint _txID) external onlyAdmin txExists(_txID) notApproved(_txID) notExecuted(_txID) {
        approved[_txID][msg.sender] = true;
        emit Approve(msg.sender, _txID);
    }

    function getApprovalCount(uint _txID) public view returns (uint count) {
        for (uint i; i < admins.length; i++) {
            if(approved[_txID][msg.sender]) {
                count += 1;
            }
        }

    }

    // function execute(uint _txID) external txExists(_txID) notExecuted(_txID) {
    //     require(getApprovalCount(_txID) >= required, "not enough approvals");
    //     Transaction storage transaction = transactions[_txID];
    //     transaction.executed = true;
        
    //     (bool success, ) = transaction.to.call{value: transaction.value}(
    //         transaction.data
    //     );
    //     require(success, "transaction failed");
    //     emit Execute(_txID);
    // }

    function execute(uint _txID) external txExists(_txID) notExecuted(_txID) {  //isGovernor?
        require(getApprovalCount(_txID) >= required, "not enough approvals");
        Proposal storage proposal = proposals[_txID];
        proposal.executed = true;

        if(proposal.method) {
            testNaira tNaira = testNaira(gNairaContractAddress);
            tNaira.mintTokens(proposal.value, proposal. user);

        } else if(!proposal.method) {

        }
        
        // (bool success, ) = transaction.to.call{value: transaction.value}(
        //     transaction.data
        // );
        // require(success, "transaction failed");
        emit Execute(_txID);
    }

    function revoke(uint _txID) external onlyAdmin txExists(_txID) notExecuted(_txID) {
        require(approved[_txID][msg.sender], "transaction not approved");
        approved[_txID][msg.sender] = false;
        emit Revoke(msg.sender, _txID);
    } 
}