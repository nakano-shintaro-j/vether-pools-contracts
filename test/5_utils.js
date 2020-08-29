/*
################################################
Creates 3 tokens and stakes them
################################################
*/

const assert = require("chai").assert;
const truffleAssert = require('truffle-assertions');
var BigNumber = require('bignumber.js');

const _ = require('./utils.js');
const math = require('./math.js');
const help = require('./helper.js');

var BASE = artifacts.require("./BaseMinted.sol");
var UTILS = artifacts.require("./Utils.sol");

var base; var utils;
var acc0; var acc1; var acc2; var acc3;

contract('BASE', function (accounts) {
    constructor(accounts)
    mathCheck()
})


//################################################################
// CONSTRUCTION
function constructor(accounts) {
    acc0 = accounts[0]; acc1 = accounts[1]; acc2 = accounts[2]; acc3 = accounts[3]

    it("constructor events", async () => {

        base = await BASE.new()
        utils = await UTILS.new(base.address)
        console.log(`Acc0: ${acc0}`)
        console.log(`Acc1: ${acc1}`)
    });
}


async function mathCheck() {
    const a = _.getBN(1*10**18)
    const A = _.getBN(10*10**18)
    const v = _.getBN(10*10**18)
    const V = _.getBN(100*10**18)
    const s = _.getBN(1000)
    const T = _.getBN(10000)

    it(`Checks staking`, async () => {
        let base = await utils.calcStakeUnits(a, A.plus(a), v, V.plus(v))
        let js = math.calcStakeUnits(a, A.plus(a), v, V.plus(v))
        assert.equal(_.BN2Str(base), _.BN2Str(js))
        assert.equal(_.BN2Str(base), '5500000000000000000')
    })

    it(`Checks assym withdrawal`, async () => {
        let base = await utils.calcAsymmetricShare(s, T, V)
        let js = math.calcAsymmetricShare(s, T, V)
        assert.equal(_.BN2Str(base), _.BN2Str(js))
        assert.equal(_.BN2Str(base), '18100000000000000000')
    })

    it(`Checks swapping`, async () => {
        let base = await utils.calcSwapOutput(a, A, V)
        let js = math.calcSwapOutput(a, A, V)
        assert.equal(_.BN2Str(base), _.BN2Str(js))
        assert.equal(_.BN2Str(base), '8264462809917355371')
    })

    it(`Checks swapping fee`, async () => {
        let base = await utils.calcSwapFee(a, A, V)
        let js = math.calcSwapFee(a, A, V)
        assert.equal(_.BN2Str(base), _.BN2Str(js))
        assert.equal(_.BN2Str(base), '826446280991735537')
        // console.log(_.BN2Str(base), _.BN2Str(js))
    })

    it(`Checks swapping fee`, async () => {
        const a = _.getBN(1000000000000000000)
        const A = _.getBN(100000000000000000)
        const V = _.getBN(10000000000000000000)
        let base = await utils.calcSwapFee(a, A, V)
        let js = math.calcSwapFee(a, A, V)
        assert.equal(_.BN2Str(base), _.BN2Str(js))
        assert.equal(_.BN2Str(base), '8264462809917355371')
        console.log(_.BN2Str(base), _.BN2Str(js))
    })
}