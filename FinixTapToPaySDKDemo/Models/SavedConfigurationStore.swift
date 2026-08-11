//
//  SavedConfigurationStore.swift
//  FinixTapToPaySDKDemo
//
//  Created by Tom Nguyen on 8/11/26.
//

import FinixTapToPaySDK
import Foundation
import Security

/// Persists the entered configuration across launches in the Keychain, one saved configuration per environment.
enum SavedConfigurationStore {

    /// Returns false when the write fails, leaving any previously saved configuration intact.
    static func save(_ configuration: TapToPayConfiguration) -> Bool {
        let snapshot = Snapshot(
            username: configuration.credentials.username,
            password: configuration.credentials.password,
            merchantId: configuration.merchant.merchantId,
            merchantMid: configuration.merchant.merchantMid,
            merchantName: configuration.merchant.merchantName,
            deviceId: configuration.deviceId
        )

        guard let data = try? JSONEncoder().encode(snapshot),
              Keychain.save(data, account: storageKey(for: configuration.environment))
        else {
            return false
        }

        UserDefaults.standard.set(
            storageKey(for: configuration.environment),
            forKey: lastSelectedEnvironmentKey
        )
        return true
    }

    static func load(for environment: TapToPayEnvironment) -> TapToPayConfiguration? {
        guard let data = Keychain.load(account: storageKey(for: environment)),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            return nil
        }

        return TapToPayConfiguration(
            credentials: TapToPayConfiguration.APICredentials(
                username: snapshot.username,
                password: snapshot.password
            ),
            merchant: TapToPayConfiguration.MerchantInfo(
                merchantId: snapshot.merchantId,
                merchantMid: snapshot.merchantMid,
                merchantName: snapshot.merchantName
            ),
            environment: environment,
            deviceId: snapshot.deviceId,
            transactionOptions: TapToPayConfiguration.TransactionOptions(
                returnReadResultImmediately: true,
                autoPrepareOnForeground: true
            )
        )
    }

    static func loadForLastSelectedEnvironment() -> TapToPayConfiguration? {
        let environment: TapToPayEnvironment =
            UserDefaults.standard.string(forKey: lastSelectedEnvironmentKey) == "production"
                ? .production
                : .sandbox
        return load(for: environment)
    }

    // MARK: - Private

    private struct Snapshot: Codable {
        let username: String
        let password: String
        let merchantId: String
        let merchantMid: String
        let merchantName: String
        let deviceId: String
    }

    private static let lastSelectedEnvironmentKey = "lastSelectedEnvironment"

    private static func storageKey(for environment: TapToPayEnvironment) -> String {
        environment == .production ? "production" : "sandbox"
    }
}

/// Minimal generic-password Keychain wrapper (device-only, available after first unlock).
private enum Keychain {
    private static let service = "com.finix.FinixTapToPaySDKDemo.configuration"

    static func save(_ data: Data, account: String) -> Bool {
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        // Update in place so a failed write never destroys the previous value; add only
        // when no item exists yet.
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        return status == errSecSuccess
    }

    static func load(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
