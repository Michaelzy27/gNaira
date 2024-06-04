//import Web3 from 'web3';

document.getElementById("send").addEventListener("click", connectWallet);

function send() {
    document.getElementById("walletaddress").value = "00x"
}

document.getElementById("connect").addEventListener("click", connectWallet);

function connect() {
    document.getElementById("walletaddress").value = "65400x"
}

var account = null;
var contract = null;

const ABI = [{"inputs":[],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[],"name":"_totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"spender","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"remaining","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"success","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"balance","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"user","type":"address"}],"name":"blacklistUser","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"burnTokens","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getGovernor","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"isBlacklisted","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"mintTokens","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"user","type":"address"}],"name":"removeBlacklist","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_governor","type":"address"}],"name":"setGovernor","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address payable","name":"_mSigAddress","type":"address"}],"name":"setMultiSigAddress","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"submitBurn","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"submitMint","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"success","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"sender","type":"address"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"success","type":"bool"}],"stateMutability":"nonpayable","type":"function"}];
const contractAddress = "0xAAE72899688Cfca7236afe5AEd68AE7Ed752cCFf";

async function connectWallet() {
        if(window.ethereum) {
            var web3 = new Web3(window.ethereum);
            await window.ethereum.send('eth_requestAccounts');
            var accounts = await web3.eth.getAccounts();
            account = accounts[0];
            document.getElementById("connect").textContent = account;

            contract = new web3.eth.Contract(ABI, contractAddress);
        } else {
            alert("please install metamask wallet!")
        }
}

async function transfer() {

    if(contract == null) {
        console.error("Contract does not exist!");
        return;
    }

    const address = document.getElementById("walletaddress").value;
    const amount =  document.getElementById("walletamount").value;

    await contract.methods.transfer(address, amount).send({from: account});

}

async function getUserBalance() {

    if(contract == null) {
        console.error("Contract does not exist!");
        return;
    }

    const _userBalance = await contract.methods.balanceOf(account).call();
    document.getElementById("mlzybalance").textContent = _userBalance + " $MLZY";

}

async function mintTokens() {

    if(contract == null) {
        console.error("Contract does not exist!");
        return;
    }

    const _amount = document.getElementById("mintamount").value;

    try {
        await contract.methods.mintTokens(_amount, account).send({from: account});
        alert("mint successful")
    } catch(error) {
        console.log(error);

    }
       
}

async function getTotalSupply() {

    if(contract == null) {
        console.error("Contract does not exist!");
        return;
    }

    const _supply = await contract.methods.totalSupply().call();
    console.log(_supply);
    document.getElementById("mlzysupplyy").textContent = _supply + " $MLZY";

}

async function burnTokens() {
    if(contract == null) {
        console.error("Contract does not exist!");
        return;
    }

    const _amount = document.getElementById("burnamount").value;

    try {
        await contract.methods.mintTokens(_amount, account).send({from: account});
        alert("burn successful")
    } catch(error) {
        console.log(error);

    }
}

async function blacklist() {
    if(contract == null) {
        console.error("Contract does not exist!");
        return;
    }

    const _address = document.getElementById("blacklistaddress").value;

    try {
        await contract.methods.blacklistUser(_address).send({from: account});
        alert("blacklist successful")
    } catch(error) {
        console.log(error);

    }
}

async function unBlacklist() {
    if(contract == null) {
        console.error("Contract does not exist!");
        return;
    }

    const _address = document.getElementById("unblacklistaddress").value;

    try {
        await contract.methods.removeBlacklist(_address).send({from: account});
        alert("unblacklist successful")
    } catch(error) {
        console.log(error);

    }
}