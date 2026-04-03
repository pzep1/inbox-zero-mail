import SwiftUI

public enum MailDesignTokens {
    // Backgrounds
    public static let background = Color(red: 0.96, green: 0.97, blue: 0.98)
    public static let sidebar = Color(red: 0.95, green: 0.96, blue: 0.98)
    public static let sidebarSurface = Color(red: 0.91, green: 0.93, blue: 0.96)

    // Surfaces
    public static let surface = Color.white
    public static let surfaceMuted = Color(red: 0.97, green: 0.97, blue: 0.98)

    // Accent
    public static let accent = Color(red: 0.25, green: 0.52, blue: 0.96)
    public static let accentStrong = Color(red: 0.18, green: 0.42, blue: 0.84)

    // Status
    public static let unread = Color(red: 0.25, green: 0.52, blue: 0.96)
    public static let selected = Color(red: 0.93, green: 0.95, blue: 1.00)

    // Chips
    public static let chipBackground = Color(red: 0.92, green: 0.95, blue: 1.00)

    // Text
    public static let textPrimary = Color(red: 0.10, green: 0.11, blue: 0.15)
    public static let textSecondary = Color(red: 0.45, green: 0.47, blue: 0.54)
    public static let textTertiary = Color(red: 0.62, green: 0.64, blue: 0.70)

    // Sidebar text
    public static let sidebarText = Color(red: 0.14, green: 0.17, blue: 0.22)
    public static let sidebarMuted = Color(red: 0.42, green: 0.47, blue: 0.55)
    public static let sidebarHover = Color(red: 0.25, green: 0.52, blue: 0.96).opacity(0.10)
    public static let sidebarSelected = Color(red: 0.25, green: 0.52, blue: 0.96).opacity(0.18)

    // Borders & Shadows
    public static let border = Color.black.opacity(0.06)
    public static let divider = Color.black.opacity(0.06)
    public static let shadow = Color.black.opacity(0.06)
}
