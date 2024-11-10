require("dotenv").config();
const Web3 = require("web3");

// Load environment variables
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const INFURA_API_URL = process.env.INFURA_API_URL;

// Initialize Web3
const web3 = new Web3(new Web3.providers.HttpProvider(INFURA_API_URL));

// Set up account
const account = web3.eth.accounts.privateKeyToAccount(PRIVATE_KEY);
web3.eth.accounts.wallet.add(account);
web3.eth.defaultAccount = account.address;

console.log(`Bot is running with account: ${account.address}`);

// Sample contract information
const contractAddress = "<YOUR_CONTRACT_ADDRESS>"; // Contract you want to interact with
const contractABI = [
  /* ABI of the contract */
];

const contract = new web3.eth.Contract(contractABI, contractAddress);

async function checkBalance() {
  try {
    const balance = await web3.eth.getBalance(account.address);
    console.log(`Current Balance: ${web3.utils.fromWei(balance, "ether")} ETH`);
  } catch (error) {
    console.error("Error fetching balance:", error);
  }
}

async function sendTransaction() {
  const tx = {
    from: account.address,
    to: "<RECIPIENT_ADDRESS>", // Replace with the recipient's address
    value: web3.utils.toWei("0.01", "ether"),
    gas: 21000,
  };

  try {
    const receipt = await web3.eth.sendTransaction(tx);
    console.log("Transaction successful:", receipt);
  } catch (error) {
    console.error("Transaction failed:", error);
  }
}

async function listenToEvents() {
  contract.events
    .SomeEvent({ fromBlock: "latest" }) // Replace `SomeEvent` with an actual event from the contract
    .on("data", (event) => {
      console.log("Event received:", event);
      // You can perform actions here in response to the event
    })
    .on("error", (error) => {
      console.error("Event listening error:", error);
    });
}

async function runBot() {
  await checkBalance(); // Check balance before any operations
  listenToEvents(); // Start listening to contract events

  // Send a  transaction every 5 minutes
  setInterval(async () => {
    console.log("Sending transaction...");
    await sendTransaction();
  }, 300000); //  5 minutes
}

runBot().catch((error) => {
  console.error("Bot encountered an error:", error);
});
