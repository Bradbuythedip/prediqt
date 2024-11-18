import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const PrediQt = await ethers.getContractFactory("PrediQt");
  const prediqt = await PrediQt.deploy();

  await prediqt.deployed();

  console.log("PrediQt deployed to:", prediqt.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});