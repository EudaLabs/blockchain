const hre = require("hardhat");

async function main() {
  // Get the contract factory
  const MyToken = await hre.ethers.getContractFactory("MyToken");

  // Get the deployer's address
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy the contract
  const maxSupply = hre.ethers.utils.parseEther("1000000"); // 1 million tokens
  const treasuryWallet = deployer.address; // Using deployer as treasury for now
  const myToken = await MyToken.deploy(maxSupply, treasuryWallet);

  // Wait for deployment
  await myToken.deployed();

  console.log("MyToken deployed to:", myToken.address);
  console.log("Max Supply:", hre.ethers.utils.formatEther(maxSupply));
  console.log("Treasury Wallet:", treasuryWallet);

  // Verify contract on BSCScan (only for testnet/mainnet)
  if (network.name !== "hardhat") {
    console.log("Waiting for block confirmations...");
    await myToken.deployTransaction.wait(6); // Wait for 6 block confirmations

    console.log("Verifying contract...");
    await hre.run("verify:verify", {
      address: myToken.address,
      constructorArguments: [maxSupply, treasuryWallet],
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 