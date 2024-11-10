require("dotenv").config();
const Web3 = require("web3");

// Load environment variables
const INFURA_API_URL = process.env.INFURA_API_URL;
const GAS_THRESHOLD = process.env.GAS_THRESHOLD || 20; // Default to 20 gwei if not set

// Initialize Web3
const web3 = new Web3(new Web3.providers.HttpProvider(INFURA_API_URL));

async function getGasPrices() {
  try {
    const gasPrices = await web3.eth.getGasPrice(); // Gas price in wei
    const gasPriceInGwei = web3.utils.fromWei(gasPrices, "gwei"); // Convert to gwei
    console.log(`Current gas price: ${gasPriceInGwei} Gwei`);

    return parseFloat(gasPriceInGwei);
  } catch (error) {
    console.error("Error fetching gas price:", error);
    return null;
  }
}

async function checkGasPrice() {
  const gasPrice = await getGasPrices();
  if (gasPrice && gasPrice < GAS_THRESHOLD) {
    console.log(
      `🚨 Gas price alert! Current gas price is ${gasPrice} Gwei, which is below the threshold of ${GAS_THRESHOLD} Gwei.`
    );
    // Here, you can add code to send an alert (e.g., SMS, email)
  } else {
    console.log(`Gas price is ${gasPrice} Gwei, above the threshold of ${GAS_THRESHOLD} Gwei.`);
  }
}

// Run the bot every minute to check gas prices
setInterval(async () => {
  console.log("Checking gas prices...");
  await checkGasPrice();
}, 60000); // 1 minute
