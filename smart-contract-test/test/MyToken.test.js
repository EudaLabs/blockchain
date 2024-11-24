const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MyToken", () => {
    let MyToken;
    let myToken;
    let owner;
    let addr1;
    let addr2;
    let treasuryWallet;
    const MAX_SUPPLY = ethers.utils.parseEther("10000000"); // 10 million tokens

    beforeEach(async () => {
        [owner, addr1, addr2, treasuryWallet] = await ethers.getSigners();
        MyToken = await ethers.getContractFactory("MyToken");
        myToken = await MyToken.deploy(MAX_SUPPLY, treasuryWallet.address);
        await myToken.deployed();
    });

    describe("Deployment", () => {
        it("Should set the correct initial parameters", async () => {
            expect(await myToken.maxSupply()).to.equal(MAX_SUPPLY);
            expect(await myToken.treasuryWallet()).to.equal(treasuryWallet.address);
            expect(await myToken.whitelisted(owner.address)).to.be.true;
            expect(await myToken.whitelisted(treasuryWallet.address)).to.be.true;
            expect(await myToken.tradingEnabled()).to.be.false;
        });

        it("Should set correct initial token distribution", async () => {
            expect(await myToken.totalSupply()).to.equal(MAX_SUPPLY);
            expect(await myToken.balanceOf(owner.address)).to.equal(MAX_SUPPLY);
        });

        it("Should set correct initial limits", async () => {
            const [maxTx, maxWallet, maxSell] = await myToken.getLimits();
            expect(maxTx).to.equal(MAX_SUPPLY.mul(1).div(100)); // 1%
            expect(maxWallet).to.equal(MAX_SUPPLY.mul(2).div(100)); // 2%
            expect(maxSell).to.equal(MAX_SUPPLY.mul(1).div(100)); // 1%
        });
    });

    describe("Trading Controls", () => {
        it("Should not allow trading before enabled", async () => {
            await expect(
                myToken.connect(addr1).transfer(addr2.address, 100)
            ).to.be.revertedWith("Trading not enabled");
        });

        it("Should enable trading correctly", async () => {
            await myToken.enableTrading();
            expect(await myToken.tradingEnabled()).to.be.true;
            const tradingEnabledAt = await myToken.tradingEnabledAt();
            expect(tradingEnabledAt).to.be.gt(0);
        });

        it("Should enforce anti-bot protection after trading enabled", async () => {
            await myToken.enableTrading();
            await expect(
                myToken.connect(addr1).transfer(addr2.address, 100)
            ).to.be.revertedWith("Anti-bot: Trading restricted");
        });
    });

    describe("Fee System", () => {
        beforeEach(async () => {
            await myToken.enableTrading();
            // Move past anti-bot timer
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");
            // Set up DEX pair
            await myToken.setDexPair(addr2.address, true);
        });

        it("Should apply correct buy fees", async () => {
            const amount = ethers.utils.parseEther("100");
            // Transfer to DEX pair first
            await myToken.transfer(addr2.address, amount);
            
            // Simulate buy from DEX pair
            await myToken.connect(addr2).transfer(addr1.address, amount);
            
            const expectedFee = amount.mul(3).div(1000); // 0.3% buy fee
            expect(await myToken.balanceOf(addr1.address)).to.equal(amount.sub(expectedFee));
        });

        it("Should apply correct sell fees", async () => {
            const amount = ethers.utils.parseEther("100");
            // Transfer to user first
            await myToken.transfer(addr1.address, amount);
            
            // Simulate sell to DEX pair
            await myToken.connect(addr1).transfer(addr2.address, amount);
            
            const expectedFee = amount.mul(8).div(1000); // 0.8% sell fee
            expect(await myToken.balanceOf(addr2.address)).to.equal(amount.sub(expectedFee));
        });
    });

    describe("Reward System", () => {
        beforeEach(async () => {
            await myToken.enableTrading();
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");
        });

        it("Should accumulate reward points correctly", async () => {
            const amount = ethers.utils.parseEther("1000");
            await myToken.transfer(addr1.address, amount);
            
            const points = await myToken.rewardPoints(owner.address);
            expect(points).to.be.gt(0);
        });

        it("Should allow claiming rewards", async () => {
            const amount = ethers.utils.parseEther("1000");
            await myToken.transfer(addr1.address, amount);
            
            // Generate some rewards
            const rewardPoolBefore = await myToken.rewardPoolBalance();
            expect(rewardPoolBefore).to.be.gt(0);
            
            // Claim rewards
            await myToken.claimRewards();
            
            const rewardPoolAfter = await myToken.rewardPoolBalance();
            expect(rewardPoolAfter).to.be.lt(rewardPoolBefore);
        });
    });

    describe("Owner Functions", () => {
        it("Should set fees correctly", async () => {
            await myToken.setFees(20, 30); // 2% buy, 3% sell
            const tokenomics = await myToken.getTokenomics();
            expect(tokenomics._buyFee).to.equal(20);
            expect(tokenomics._sellFee).to.equal(30);
        });

        it("Should not allow fees above maximum", async () => {
            await expect(
                myToken.setFees(51, 30)
            ).to.be.revertedWith("Fee too high");
        });

        it("Should set limits correctly", async () => {
            const newMaxTx = MAX_SUPPLY.mul(2).div(100);
            const newMaxWallet = MAX_SUPPLY.mul(3).div(100);
            const newMaxSell = MAX_SUPPLY.mul(2).div(100);
            
            await myToken.setLimits(newMaxTx, newMaxWallet, newMaxSell);
            
            const [maxTx, maxWallet, maxSell] = await myToken.getLimits();
            expect(maxTx).to.equal(newMaxTx);
            expect(maxWallet).to.equal(newMaxWallet);
            expect(maxSell).to.equal(newMaxSell);
        });
    });

    describe("Flash Loan Protection", () => {
        beforeEach(async () => {
            await myToken.enableTrading();
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");
        });

        it("Should apply flash loan fee for same block transactions", async () => {
            const amount = ethers.utils.parseEther("100");
            await myToken.transfer(addr1.address, amount);

            // Try to transfer in same block
            await myToken.connect(addr1).transfer(addr2.address, amount.div(2));
            const flashFee = amount.div(2).mul(FLASH_LOAN_FEE).div(FEE_DENOMINATOR);
            
            expect(await myToken.balanceOf(addr1.address))
                .to.equal(amount.div(2).sub(flashFee));
        });
    });

    describe("Fee Distribution", () => {
        beforeEach(async () => {
            await myToken.enableTrading();
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");
            await myToken.setDexPair(addr2.address, true);
        });

        it("Should distribute fees correctly on sells", async () => {
            const amount = ethers.utils.parseEther("1000");
            await myToken.transfer(addr1.address, amount);

            // Track balances before sell
            const treasuryBefore = await myToken.balanceOf(treasuryWallet.address);
            const contractBefore = await myToken.balanceOf(myToken.address);
            const totalSupplyBefore = await myToken.totalSupply();

            // Simulate sell
            await myToken.connect(addr1).transfer(addr2.address, amount);

            // Calculate expected fees
            const totalFee = amount.mul(sellFee).div(FEE_DENOMINATOR);
            const burnShare = totalFee.mul(40).div(100);
            const treasuryShare = totalFee.mul(40).div(100);
            const rewardShare = totalFee.mul(20).div(100);

            // Verify fee distribution
            expect(await myToken.balanceOf(treasuryWallet.address))
                .to.equal(treasuryBefore.add(treasuryShare));
            expect(await myToken.balanceOf(myToken.address))
                .to.equal(contractBefore.add(rewardShare));
            expect(await myToken.totalSupply())
                .to.equal(totalSupplyBefore.sub(burnShare));
        });
    });

    describe("Blacklist", () => {
        it("Should prevent blacklisted addresses from trading", async () => {
            await myToken.enableTrading();
            await ethers.provider.send("evm_increaseTime", [61]);
            
            // Blacklist addr1
            await myToken.setBlacklist(addr1.address, true);
            
            await expect(
                myToken.transfer(addr1.address, 100)
            ).to.be.revertedWith("Blacklisted");
        });
    });

    describe("Max Limits", () => {
        beforeEach(async () => {
            await myToken.enableTrading();
            await ethers.provider.send("evm_increaseTime", [61]);
            await myToken.setDexPair(addr2.address, true);
        });

        it("Should enforce max transaction limit", async () => {
            const maxTx = await myToken.maxTransactionAmount();
            await expect(
                myToken.transfer(addr1.address, maxTx.add(1))
            ).to.be.revertedWith("Exceeds max tx");
        });

        it("Should enforce max wallet limit", async () => {
            const maxWallet = await myToken.maxWalletAmount();
            await expect(
                myToken.transfer(addr1.address, maxWallet.add(1))
            ).to.be.revertedWith("Exceeds max wallet");
        });

        it("Should enforce max sell limit", async () => {
            const amount = ethers.utils.parseEther("1000");
            await myToken.transfer(addr1.address, amount);
            const maxSell = await myToken.maxSellAmount();
            
            await expect(
                myToken.connect(addr1).transfer(addr2.address, maxSell.add(1))
            ).to.be.revertedWith("Exceeds max sell");
        });
    });

    describe("Cooldown", () => {
        beforeEach(async () => {
            await myToken.enableTrading();
            await ethers.provider.send("evm_increaseTime", [61]);
        });

        it("Should enforce cooldown between trades", async () => {
            await myToken.transfer(addr1.address, 1000);
            
            await expect(
                myToken.connect(addr1).transfer(addr2.address, 100)
            ).to.be.revertedWith("Cooldown active");
        });

        it("Should allow trading after cooldown", async () => {
            await myToken.transfer(addr1.address, 1000);
            
            // Move time forward past cooldown
            await ethers.provider.send("evm_increaseTime", [61]);
            await ethers.provider.send("evm_mine");
            
            await expect(
                myToken.connect(addr1).transfer(addr2.address, 100)
            ).to.not.be.reverted;
        });
    });

    describe("Reward System", () => {
        beforeEach(async () => {
            await myToken.enableTrading();
            await ethers.provider.send("evm_increaseTime", [61]);
            await myToken.setDexPair(addr2.address, true);
        });

        it("Should not allow claiming with no points", async () => {
            await expect(
                myToken.connect(addr1).claimRewards()
            ).to.be.revertedWith("No rewards");
        });

        it("Should not allow claiming with empty reward pool", async () => {
            // Give points but keep reward pool empty
            const amount = ethers.utils.parseEther("1000");
            await myToken.transfer(addr1.address, amount);
            await expect(
                myToken.claimRewards()
            ).to.be.revertedWith("No rewards in pool");
        });

        it("Should accumulate reward points based on threshold", async () => {
            const threshold = await myToken.rewardThreshold();
            const amount = threshold.mul(2); // Should give 2 points
            
            await myToken.transfer(addr1.address, amount);
            expect(await myToken.rewardPoints(owner.address)).to.equal(2);
        });
    });

    describe("View Functions", () => {
        it("Should return correct tokenomics", async () => {
            const tokenomics = await myToken.getTokenomics();
            expect(tokenomics._maxSupply).to.equal(MAX_SUPPLY);
            expect(tokenomics._totalSupply).to.equal(MAX_SUPPLY);
            expect(tokenomics._buyFee).to.equal(3);
            expect(tokenomics._sellFee).to.equal(8);
        });

        it("Should return correct limits", async () => {
            const [maxTx, maxWallet, maxSell] = await myToken.getLimits();
            expect(maxTx).to.equal(MAX_SUPPLY.mul(1).div(100));
            expect(maxWallet).to.equal(MAX_SUPPLY.mul(2).div(100));
            expect(maxSell).to.equal(MAX_SUPPLY.mul(1).div(100));
        });
    });

    describe("Dynamic Fee System", () => {
        beforeEach(async () => {
            await myToken.enableTrading();
            await ethers.provider.send("evm_increaseTime", [61]);
            await myToken.setDexPair(addr2.address, true);
        });

        it("Should adjust fees based on volume", async () => {
            const amount = ethers.utils.parseEther("1000");
            await myToken.transfer(addr2.address, amount); // DEX pair

            // Simulate multiple trades to increase volume
            for(let i = 0; i < 5; i++) {
                await myToken.connect(addr2).transfer(addr1.address, amount.div(5));
            }

            const multiplier = await myToken.dynamicFeeMultiplier();
            expect(multiplier).to.be.gt(100); // Should increase from base 100
        });

        it("Should not exceed maximum fee multiplier", async () => {
            const amount = ethers.utils.parseEther("10000");
            await myToken.transfer(addr2.address, amount);

            // Generate massive volume
            for(let i = 0; i < 10; i++) {
                await myToken.connect(addr2).transfer(addr1.address, amount.div(10));
            }

            const multiplier = await myToken.dynamicFeeMultiplier();
            expect(multiplier).to.be.lte(await myToken.MAX_DYNAMIC_FEE_MULTIPLIER());
        });
    });

    describe("Liquidity Management", () => {
        it("Should set liquidity pool correctly", async () => {
            await myToken.setLiquidityPool(addr1.address);
            expect(await myToken.liquidityPool()).to.equal(addr1.address);
        });

        it("Should toggle auto-liquidity", async () => {
            await myToken.setAutoLiquidity(true);
            expect(await myToken.autoLiquidity()).to.be.true;
        });

        it("Should not add liquidity below minimum threshold", async () => {
            await myToken.setAutoLiquidity(true);
            const smallAmount = ethers.utils.parseEther("100");
            
            // Transfer small amount to contract
            await myToken.transfer(myToken.address, smallAmount);
            
            // Check that totalLiquidityAdded hasn't changed
            const liquidityBefore = await myToken.totalLiquidityAdded();
            await myToken.transfer(addr1.address, 1); // Trigger potential liquidity add
            expect(await myToken.totalLiquidityAdded()).to.equal(liquidityBefore);
        });
    });

    describe("Trading Analytics", () => {
        beforeEach(async () => {
            await myToken.enableTrading();
            await ethers.provider.send("evm_increaseTime", [61]);
            await myToken.setDexPair(addr2.address, true);
        });

        it("Should record trade history correctly", async () => {
            const amount = ethers.utils.parseEther("100");
            await myToken.transfer(addr1.address, amount);

            const [timestamps, amounts, isBuys, prices] = await myToken.getTradeHistory(addr1.address, 1);
            expect(amounts[0]).to.equal(amount);
            expect(isBuys[0]).to.be.true;
        });

        it("Should track daily volume", async () => {
            const amount = ethers.utils.parseEther("100");
            await myToken.transfer(addr1.address, amount);

            const volumes = await myToken.getDailyVolume(1);
            expect(volumes[0]).to.equal(amount);
        });

        it("Should increment total trades counter", async () => {
            const initialTrades = await myToken.totalTrades();
            await myToken.transfer(addr1.address, 1000);
            expect(await myToken.totalTrades()).to.equal(initialTrades.add(1));
        });
    });

    describe("Multi-Signature Operations", () => {
        let signer1;
        let signer2;
        let operationId;

        beforeEach(async () => {
            [owner, signer1, signer2] = await ethers.getSigners();
            await myToken.addSigner(signer1.address);
            await myToken.addSigner(signer2.address);
            
            // Create a test operation (e.g., setting new fees)
            const operationData = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                [20, 30] // New buy and sell fees
            );
            operationId = ethers.utils.keccak256(
                ethers.utils.defaultAbiCoder.encode(
                    ['bytes32', 'bytes', 'uint256'],
                    [await myToken.OP_SET_FEES(), operationData, await ethers.provider.getBlockNumber()]
                )
            );
            await myToken.connect(owner).createOperation(await myToken.OP_SET_FEES(), operationData);
        });

        it("Should require multiple signatures", async () => {
            await myToken.connect(signer1).signOperation(operationId);
            
            await expect(
                myToken.executeOperation(operationId)
            ).to.be.revertedWith("Insufficient signatures");
        });

        it("Should execute after required signatures", async () => {
            await myToken.connect(signer1).signOperation(operationId);
            await myToken.connect(signer2).signOperation(operationId);
            
            // Wait for time lock
            await ethers.provider.send("evm_increaseTime", [86400]); // 1 day
            await ethers.provider.send("evm_mine");
            
            await myToken.executeOperation(operationId);
            
            const operation = await myToken.getOperationInfo(operationId);
            expect(operation.executed).to.be.true;
        });

        it("Should not allow duplicate signatures", async () => {
            await myToken.connect(signer1).signOperation(operationId);
            
            await expect(
                myToken.connect(signer1).signOperation(operationId)
            ).to.be.revertedWith("Already signed");
        });
    });

    describe("Holder Management", () => {
        it("Should track holders correctly", async () => {
            const initialCount = await myToken.getHolderCount();
            await myToken.transfer(addr1.address, 1000);
            expect(await myToken.getHolderCount()).to.equal(initialCount.add(1));
        });

        it("Should remove holders when balance becomes zero", async () => {
            await myToken.transfer(addr1.address, 1000);
            const countAfterAdd = await myToken.getHolderCount();
            
            await myToken.connect(addr1).transfer(owner.address, 1000);
            expect(await myToken.getHolderCount()).to.equal(countAfterAdd.sub(1));
        });
    });

    describe("Emergency Functions", () => {
        it("Should allow emergency pause by signer", async () => {
            await myToken.emergencyPause();
            expect(await myToken.paused()).to.be.true;
        });

        it("Should prevent transfers when paused", async () => {
            await myToken.emergencyPause();
            await expect(
                myToken.transfer(addr1.address, 1000)
            ).to.be.revertedWith("Pausable: paused");
        });

        it("Should allow emergency unpause by signer", async () => {
            await myToken.emergencyPause();
            await myToken.emergencyUnpause();
            expect(await myToken.paused()).to.be.false;
        });
    });
}); 