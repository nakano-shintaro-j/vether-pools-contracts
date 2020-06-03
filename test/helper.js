/*
################################################
Stake based help functions to test
Useful for tests that require state
################################################
*/

var BigNumber = require('bignumber.js');
const _ = require('./utils')
const math = require('./math.js');

const usdPool = { "asset": (2 * _.one).toString(), "mai": (2 * _.one).toString() };

async function calcValueInVeth(instance, token) {
  var result;
  var assetBal; var maiBal; 
  if (token == _.addressETH) {
    assetBal = new BigNumber((await instance.mapAsset_ExchangeData(token)).asset);
    maiBal = new BigNumber((await instance.mapAsset_ExchangeData(token)).vether);
    result = (_.oneBN.times(maiBal)).div(assetBal)
  } else {
    assetBal = new BigNumber((await instance.mapAsset_ExchangeData(token)).asset);
    maiBal = new BigNumber((await instance.mapAsset_ExchangeData(token)).vether);
    result = (_.oneBN.times(maiBal)).div(assetBal)
  }
  return result.toFixed()
}

async function calcValueInAsset() {
  var usdBal = new BigNumber(usdPool.asset)
  var maiBal = new BigNumber(usdPool.mai)
  return ((_.oneBN.times(usdBal)).div(maiBal)).toFixed()
}
async function calcEtherPriceInUSD(instance, amount) {
  const _amount = new BigNumber(amount)
  const etherPriceInVeth = new BigNumber(await calcValueInVeth(instance, _.addressETH))
  const maiPriceInUSD = new BigNumber(await calcValueInAsset())
  const ethPriceInUSD = (maiPriceInUSD.times(etherPriceInVeth)).div(_.oneBN)
  return ((_amount.times(ethPriceInUSD)).div(_.oneBN)).toFixed()
}
async function calcEtherPPinVETH(instance, amount) {
  var assetBal = new BigNumber((await instance.mapAsset_ExchangeData(_.addressETH)).asset);
  var maiBal = new BigNumber((await instance.mapAsset_ExchangeData(_.addressETH)).vether);
  const outputVeth = math.calcCLPSwap(amount, assetBal, maiBal);
  return outputVeth;
}
async function calcVETHPPInUSD(amount) {
  var usdBal = new BigNumber(usdPool.asset)
  var maiBal = new BigNumber(usdPool.mai)
  const outputUSD = math.calcCLPSwap(amount.toString(), maiBal, usdBal);
  return outputUSD;
}
async function checkLiquidateCDP(instance, _collateral, _debt) {
  var assetBal = new BigNumber((await instance.mapAsset_ExchangeData(_.addressETH)).asset);
  var maiBal = new BigNumber((await instance.mapAsset_ExchangeData(_.addressETH)).vether);
  const outputVeth = math.calcCLPLiquidation(_collateral, assetBal, maiBal);
  var canLiquidate
  if (outputVeth < _debt) {
    canLiquidate = true;
  } else {
    canLiquidate = false;
  }
  return canLiquidate;
}
async function logPool(instance, addressAsset) {
  const assetBalance = +(new BigNumber((await instance.mapPoolData(addressAsset)).asset));
  const assetVETHBalance = +(new BigNumber((await instance.mapPoolData(addressAsset)).vether));
  // const ValueInVeth = +(new BigNumber(await calcValueInVeth(instance, addressAsset)));
  // const PriceInUSD = +(new BigNumber(await calcEtherPriceInUSD(instance, amount)));
  // const PPInVETH = +(new BigNumber(await calcEtherPPinVETH(instance, amount)));
  console.log("\n-------------------Asset-Vether Details -------------------")
  console.log(`ADDRESS: ${addressAsset}`)
  console.log(`BALANCES: [ ${assetBalance / (_.one)} | ${assetVETHBalance / (_.one)} ]`)
  // console.log(`${ValueInVeth / (_.one)} VETH, $${PriceInUSD / (_.one)}`)
  // console.log('VETH PP from eth:mai   :  ', PPInVETH / (_.one))
  console.log("-----------------------------------------------------------\n")
}
async function logETHBalances(acc0, acc1, ETH) {
  const acc0AssetBal = await web3.eth.getBalance(acc0)
  const acc1AssetBal = await web3.eth.getBalance(acc1)
  const addressETHBalance = await web3.eth.getBalance(ETH)
  console.log(" ")
  console.log("----------------------ETH BALANCES---------------------")
  console.log('acc0:       ', acc0AssetBal / (_.one))
  console.log('acc1:       ', acc1AssetBal / (_.one))
  console.log('_.addressETH: ', _.addressETHBalance / (_.one))
}
async function logVETHBalances(instance, acc0, acc1, VETHAddress) {
  // instance = await VETH.deployed();
  const acc0VETHBalance = _.BN2Int(await instance.balanceOf(acc0))
  const acc1VETHBalance = _.BN2Int(await instance.balanceOf(acc1))
  const addressVETHBalance = _.BN2Int(await instance.balanceOf(VETHAddress))
  console.log(" ")
  console.log("-----------------------VETH BALANCES--------------------")
  console.log('acc0:       ', acc0VETHBalance / (_.one))
  console.log('acc1:       ', acc1VETHBalance / (_.one))
  console.log('addressVETH: ', addressVETHBalance / (_.one))

}

async function logCDP(instance, CDPAddress) {
  // instance = await VETH.deployed();
  const CDP = new BigNumber(await instance.mapAddress_MemberData.call(CDPAddress)).toFixed();
  const Collateral = new BigNumber((await instance.mapCDP_Data.call(CDP)).collateral).toFixed();
  const Debt = new BigNumber((await instance.mapCDP_Data.call(CDP)).debt).toFixed();
  console.log(" ")
  console.log("-----------------------CDP DETAILS----------------------")
  console.log('CDP:        ', CDP)
  console.log('Collateral: ', Collateral / (_.one))
  console.log('Debt:       ', Debt / (_.one))

}

module.exports = {
  logCDP: logCDP
  ,
  logVETHBalances: logVETHBalances
  ,
  logETHBalances: logETHBalances
  ,
  logPool: logPool
  ,
  checkLiquidateCDP: checkLiquidateCDP
  ,
  calcVETHPPInUSD: calcVETHPPInUSD
  ,
  calcEtherPPinVETH: calcEtherPPinVETH
  ,
  calcEtherPriceInUSD: calcEtherPriceInUSD
  ,
  calcValueInAsset: calcValueInAsset
  ,
  calcValueInVeth: calcValueInVeth
  ,


}

