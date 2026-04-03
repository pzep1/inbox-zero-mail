import Foundation
import Testing
@testable import MailCore

@Test
func threadIdentifierRetainsAccountIdentity() {
    let accountID = MailAccountID(rawValue: "gmail:alpha@example.com")
    let threadID = MailThreadID(accountID: accountID, providerThreadID: "thread-123")

    #expect(threadID.accountID == accountID)
    #expect(threadID.providerThreadID == "thread-123")
}

@Test
func identicalProviderThreadIDsRemainDistinctAcrossAccounts() {
    let first = MailThreadID(accountID: MailAccountID(rawValue: "gmail:alpha@example.com"), providerThreadID: "shared-thread")
    let second = MailThreadID(accountID: MailAccountID(rawValue: "gmail:beta@example.com"), providerThreadID: "shared-thread")

    #expect(first != second)
    #expect(first.rawValue != second.rawValue)
}

@Test
func unifiedTabsExposeExpectedTitles() {
    #expect(UnifiedTab.all.title == "All")
    #expect(UnifiedTab.unread.title == "Unread")
    #expect(UnifiedTab.starred.title == "Starred")
}

@Test
func sameMailboxNameCanModelDistinctProviderSemantics() {
    let accountID = MailAccountID(rawValue: "microsoft:gamma@example.com")
    let folder = MailboxRef(
        id: MailboxID(accountID: accountID, providerMailboxID: "inbox"),
        accountID: accountID,
        providerMailboxID: "inbox",
        displayName: "Inbox",
        kind: .folder,
        systemRole: .inbox
    )
    let category = MailboxRef(
        id: MailboxID(accountID: accountID, providerMailboxID: "Inbox"),
        accountID: accountID,
        providerMailboxID: "Inbox",
        displayName: "Inbox",
        kind: .category
    )

    #expect(folder.kind == .folder)
    #expect(category.kind == .category)
    #expect(folder != category)
}

@Test
func mailboxRefHumanizesRawProviderNames() {
    let accountID = MailAccountID(rawValue: "gmail:alpha@example.com")
    let category = MailboxRef(
        id: MailboxID(accountID: accountID, providerMailboxID: "CATEGORY_FORUMS"),
        accountID: accountID,
        providerMailboxID: "CATEGORY_FORUMS",
        displayName: "CATEGORY_FORUMS",
        kind: .category
    )
    let label = MailboxRef(
        id: MailboxID(accountID: accountID, providerMailboxID: "Label_ops"),
        accountID: accountID,
        providerMailboxID: "Label_ops",
        displayName: "Label_ops",
        kind: .label
    )

    #expect(category.displayName == "Forums")
    #expect(label.displayName == "Ops")
}

@Test
func mailboxRefNormalizesDecodedPayloads() throws {
    let json = """
    {
      "id": "gmail:alpha@example.com::mailbox::CATEGORY_PERSONAL",
      "accountID": "gmail:alpha@example.com",
      "providerMailboxID": "CATEGORY_PERSONAL",
      "displayName": "CATEGORY_PERSONAL",
      "kind": "category"
    }
    """.data(using: .utf8)!

    let mailbox = try JSONDecoder().decode(MailboxRef.self, from: json)

    #expect(mailbox.displayName == "Personal")
}

@Test
func sendMutationSerializesDraftPayload() throws {
    let draft = OutgoingDraft(
        accountID: MailAccountID(rawValue: "gmail:alpha@example.com"),
        replyMode: .reply,
        threadID: MailThreadID(accountID: MailAccountID(rawValue: "gmail:alpha@example.com"), providerThreadID: "thread-1"),
        toRecipients: [.init(name: "Taylor", emailAddress: "taylor@example.com")],
        subject: "Re: Status",
        plainBody: "All set."
    )

    let encoded = try JSONEncoder().encode(MailMutation.send(draft: draft))
    let decoded = try JSONDecoder().decode(MailMutation.self, from: encoded)

    #expect(decoded == .send(draft: draft))
}
