//
//  ChargeCalculatorTests.swift
//  FinixTapToPaySDKDemoTests
//

import Testing
@testable import FinixTapToPaySDKDemo

struct ChargeCalculatorTests {

    // MARK: - Amount parsing

    @Test(arguments: [("54.13", 5413), ("0.29", 29), ("100", 10_000), ("0.5", 50), (" 12.30 ", 1230)])
    func amountInCents_parsesDollarText(text: String, expected: Int) {
        #expect(ChargeCalculator.amountInCents(from: text) == expected)
    }

    @Test(arguments: ["", "0", "0.00", "0.001", "0.299", "abc", "12abc", "-5", "1.2.3", "1,50", "1000000"])
    func amountInCents_rejectsInvalidInput(text: String) {
        #expect(ChargeCalculator.amountInCents(from: text) == nil)
    }

    // MARK: - Tip

    @Test func tipCents_presetsOnOneHundredDollars() {
        let tips = ChargeCalculator.tipPercentPresets.map {
            ChargeCalculator.tipCents(baseCents: 10_000, percent: $0)
        }
        #expect(tips == [1800, 2000, 2200])
    }

    @Test func tipCents_truncatesSubCentRemainder() {
        // 999 * 18 / 100 = 179.82
        #expect(ChargeCalculator.tipCents(baseCents: 999, percent: 18) == 179)
    }

    @Test func customTip_stripsNonDigitsAndCapsAtSixDigits() {
        #expect(ChargeCalculator.sanitizedCustomTipDigits("1a2.3") == "123")
        #expect(ChargeCalculator.sanitizedCustomTipDigits("12345678") == "123456")
    }

    @Test(arguments: ["", "0", "00", "000", "x"])
    func customTip_rejectsEmptyAndZero(text: String) {
        #expect(ChargeCalculator.customTipCents(from: text) == nil)
    }

    @Test func customTip_digitsAreCents() {
        #expect(ChargeCalculator.customTipCents(from: "250") == 250)
    }

    // MARK: - Surcharge

    @Test func surchargeCents_threePercentOfOneHundredDollars() {
        #expect(ChargeCalculator.surchargeCents(baseCents: 10_000, basisPoints: 300) == 300)
    }

    @Test func surchargeCents_truncatesSubCentRemainder() {
        // 333 * 300 / 10000 = 9.99
        #expect(ChargeCalculator.surchargeCents(baseCents: 333, basisPoints: 300) == 9)
    }

    @Test func surchargeCents_isNilWithoutRate() {
        #expect(ChargeCalculator.surchargeCents(baseCents: 10_000, basisPoints: 0) == nil)
    }

    @Test func surchargeNotice_matchesCheckoutText() {
        #expect(
            ChargeCalculator.surchargeNotice(basisPoints: 300, surchargeCents: 300)
                == "A surcharge of 3% ($3.00) will be added if using a credit card. 0% for debit"
        )
        #expect(
            ChargeCalculator.surchargeNotice(basisPoints: 275, surchargeCents: 275)
                .hasPrefix("A surcharge of 2.75% ($2.75)")
        )
    }

    // MARK: - Signature rule

    @Test func requiresSignature_alwaysAndNever() {
        #expect(ChargeCalculator.requiresSignature(totalCents: 1, rule: .always, thresholdCents: 0))
        #expect(!ChargeCalculator.requiresSignature(totalCents: 1_000_000, rule: .never, thresholdCents: 0))
    }

    @Test func requiresSignature_thresholdIsInclusive() {
        #expect(!ChargeCalculator.requiresSignature(totalCents: 4_999, rule: .threshold, thresholdCents: 5_000))
        #expect(ChargeCalculator.requiresSignature(totalCents: 5_000, rule: .threshold, thresholdCents: 5_000))
        #expect(ChargeCalculator.requiresSignature(totalCents: 5_001, rule: .threshold, thresholdCents: 5_000))
    }

    @Test func requiresSignature_refundsNeverNeedOne() {
        #expect(!ChargeCalculator.requiresSignature(totalCents: 1, rule: .always, thresholdCents: 0, isRefund: true))
    }

    // MARK: - Worked example (TTP_Usecases.md section 7)

    @Test func workedExample_hundredDollarsWithTwentyPercentTipAndThreePercentSurcharge() {
        let base = 10_000
        let tip = ChargeCalculator.tipCents(baseCents: base, percent: 20)
        let surcharge = ChargeCalculator.surchargeCents(baseCents: base, basisPoints: 300)
        let breakdown = ChargeBreakdown(
            baseCents: base,
            tipCents: tip,
            surchargeCents: surcharge,
            collectSignature: true
        )

        #expect(tip == 2000)
        #expect(surcharge == 300)
        #expect(breakdown.tapSheetCents == 12_000)
    }

    // MARK: - Options

    @Test func defaultOptions_haveNoPreChargeStep() {
        #expect(!ChargeOptions().needsPreChargeStep)
        #expect(ChargeOptions(tipEnabled: true).needsPreChargeStep)
        #expect(ChargeOptions(surchargeBasisPoints: 300).needsPreChargeStep)
    }

    @Test func sanitized_clampsNumericFields() {
        let clamped = ChargeOptions(surchargeBasisPoints: 50_000, signatureThresholdCents: -5).sanitized()
        #expect(clamped.surchargeBasisPoints == ChargeOptions.maxSurchargeBasisPoints)
        #expect(clamped.signatureThresholdCents == 0)
    }
}
