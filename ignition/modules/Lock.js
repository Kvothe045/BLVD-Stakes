// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("TokenStakingModule", (m) => {
  // Use predefined token addresses that we'll deploy separately
  const stakingTokenAddress = m.getParameter("stakingTokenAddress", "0x5FbDB2315678afecb367f032d93F642f64180aa3");
  const rewardTokenAddress = m.getParameter("rewardTokenAddress", "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512");
  
  // Deploy the TokenStaking contract with the token addresses
  const tokenStaking = m.contract("TokenStaking", [
    stakingTokenAddress,
    rewardTokenAddress
  ], { id: "TokenStakingContract" });
  
  return { tokenStaking };
});