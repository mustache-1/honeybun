import SwiftUI
import AppKit

// Colors (the same Halloween palette the app uses)
let bgTop = Color(red: 0.086, green: 0.055, blue: 0.125)
let bgBottom = Color(red: 0.24, green: 0.11, blue: 0.30)
let card = Color(red: 0.118, green: 0.098, blue: 0.145)
let orange = Color(red: 0.96, green: 0.60, blue: 0.29)
let green = Color(red: 0.45, green: 0.85, blue: 0.55)
let softText = Color.white.opacity(0.62)
let hairline = Color.white.opacity(0.09)

struct RoundIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: 14).fill(card))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(hairline, lineWidth: 1))
    }
}

struct Stat: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(softText)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DueRow: View {
    let name: String
    let sub: String
    let amount: String
    let late: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.tv")
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.7, green: 0.6, blue: 1.0))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 17, weight: .bold))
                Text(sub).font(.system(size: 13, weight: .semibold)).foregroundColor(late ? orange : softText)
            }
            Spacer()
            Text(amount).font(.system(size: 17, weight: .bold, design: .rounded))
            Text("Paid").font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .foregroundColor(.white)
    }
}

struct TabItem: View {
    let symbol: String
    let label: String
    let on: Bool
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 21, weight: .semibold))
            Text(label).font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(on ? orange : Color.white.opacity(0.55))
        .frame(maxWidth: .infinity)
    }
}

struct HomeView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)

            // a few stars and the moon, like the website's Halloween look
            Circle().fill(Color(red: 1.0, green: 0.89, blue: 0.63)).frame(width: 46, height: 46)
                .shadow(color: orange.opacity(0.6), radius: 28)
                .position(x: 300, y: 70)

            VStack(spacing: 14) {
                // header
                HStack(spacing: 12) {
                    HStack(spacing: -10) {
                        Text("🐰").font(.system(size: 22)).frame(width: 42, height: 42)
                            .background(Circle().fill(Color(red: 1.0, green: 0.85, blue: 0.9)))
                        Text("🐻").font(.system(size: 22)).frame(width: 42, height: 42)
                            .background(Circle().fill(Color(red: 1.0, green: 0.93, blue: 0.72)))
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Good morning").font(.system(size: 13, weight: .semibold)).foregroundColor(softText)
                        Text("Us").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                    }
                    Spacer()
                    RoundIcon(symbol: "questionmark.circle")
                    RoundIcon(symbol: "gearshape")
                    RoundIcon(symbol: "message")
                }
                .padding(.top, 58)

                // hero
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Left in").font(.system(size: 16, weight: .semibold)).foregroundColor(softText)
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold)).foregroundColor(softText)
                        Text("October").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(softText)
                        Spacer()
                        Text("On track").font(.system(size: 13, weight: .bold)).foregroundColor(green)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(green.opacity(0.16)))
                    }
                    Text("$4,636.60")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        Text("Carried over from September").foregroundColor(softText)
                        Text("+$3,657.50").foregroundColor(green)
                    }.font(.system(size: 14, weight: .semibold))
                    HStack(spacing: 8) {
                        Text("This month").foregroundColor(softText)
                        Text("+$979.10").foregroundColor(green)
                        Text("Change").foregroundColor(orange)
                    }.font(.system(size: 14, weight: .semibold))
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.45))
                            Capsule().fill(LinearGradient(colors: [orange, Color(red: 1.0, green: 0.72, blue: 0.4)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * 0.62)
                        }
                    }.frame(height: 9)
                    HStack {
                        Stat(title: "Came in", value: "$2,600.00", color: green)
                        Stat(title: "Spent", value: "$1,620.90", color: .white)
                        Stat(title: "Bills due", value: "$35.98", color: .white)
                    }.padding(.top, 2)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 26).fill(card))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(hairline, lineWidth: 1))

                // Bun note
                HStack(spacing: 12) {
                    Text("🐰").font(.system(size: 22))
                    Text("38% of this month is still ours.").font(.system(size: 15, weight: .semibold)).foregroundColor(softText)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(softText)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 22).fill(card))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(hairline, lineWidth: 1))

                // Bun's tip
                HStack(alignment: .top, spacing: 12) {
                    Text("🐰").font(.system(size: 26)).frame(width: 50, height: 50)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BUN'S TIP").font(.system(size: 13, weight: .heavy)).foregroundColor(Color(red: 0.75, green: 0.62, blue: 1.0))
                        Text("Eating out is $88 over budget. No stress, next month is a fresh start.")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.19, green: 0.14, blue: 0.27)))

                // coming up
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Coming up").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                        Spacer()
                        Text("next 30 days").font(.system(size: 13, weight: .semibold)).foregroundColor(softText)
                    }
                    DueRow(name: "Netflix", sub: "Overdue, was due Oct 2", amount: "$17.99", late: true)
                    Rectangle().fill(hairline).frame(height: 1)
                    DueRow(name: "Spotify", sub: "Due Oct 16", amount: "$11.99", late: false)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 24).fill(card))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(hairline, lineWidth: 1))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

            // the native tab bar (a real iPhone draws this one itself)
            HStack {
                TabItem(symbol: "house.fill", label: "Home", on: true)
                TabItem(symbol: "calendar", label: "Plan", on: false)
                TabItem(symbol: "plus.circle.fill", label: "Add", on: false)
                TabItem(symbol: "chart.bar.fill", label: "Stats", on: false)
                TabItem(symbol: "heart.fill", label: "Together", on: false)
            }
            .padding(.top, 8).padding(.bottom, 26)
            .background(Rectangle().fill(Color(red: 0.08, green: 0.06, blue: 0.11).opacity(0.95)))
            .overlay(Rectangle().fill(hairline).frame(height: 1), alignment: .top)
        }
        .frame(width: 393, height: 852)
        .clipped()
    }
}

@MainActor
func render(to path: String) {
    let renderer = ImageRenderer(content: HomeView())
    renderer.scale = 3
    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("render failed")
        exit(1)
    }
    do { try png.write(to: URL(fileURLWithPath: path)); print("wrote \(path)") }
    catch { print("write failed: \(error)"); exit(1) }
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "home.png"
_ = NSApplication.shared
MainActor.assumeIsolated { render(to: out) }
