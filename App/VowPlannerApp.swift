import SwiftUI
import Foundation
import UIKit

// MARK: - Website Template Enum

enum WebsiteTemplate: String, CaseIterable {
    case classic = "Classic"
    case modern = "Modern"
    case romantic = "Romantic"
    
    var icon: String {
        switch self {
        case .classic: return "doc.text"
        case .modern: return "square.grid.2x2"
        case .romantic: return "heart"
        }
    }
}

// MARK: - Main App Entry Point

@main
struct VowPlannerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Storage Manager

class WebsiteGenerator {
    static let shared = WebsiteGenerator()
    
    private init() {}
    
    func generateHTML(coupleNames: String, date: String, location: String, attendingGuests: [Guest], template: WebsiteTemplate = .classic) -> String {
        switch template {
        case .classic:
            return generateClassicTemplate(coupleNames: coupleNames, date: date, location: location, guests: attendingGuests)
        case .modern:
            return generateModernTemplate(coupleNames: coupleNames, date: date, location: location, guests: attendingGuests)
        case .romantic:
            return generateRomanticTemplate(coupleNames: coupleNames, date: date, location: location, guests: attendingGuests)
        }
    }
    
    private func generateClassicTemplate(coupleNames: String, date: String, location: String, guests: [Guest]) -> String {
        let guestListHTML = guests.map { "<li>\(escapeHTML($0.name))</li>" }.joined()
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(coupleNames)) - Wedding</title>
            <style>
                body { font-family: Georgia, 'Times New Roman', serif; max-width: 800px; margin: 0 auto; padding: 20px; background: #fafafa; }
                .header { text-align: center; padding: 40px 0; border-bottom: 3px double #333; }
                h1 { color: #2c3e50; margin-bottom: 10px; font-size: 2.5em; }
                .date { color: #7f8c8d; font-size: 1.2em; font-style: italic; }
                .location { color: #95a5a6; margin-top: 10px; }
                .section { background: white; padding: 25px; margin: 20px 0; border-radius: 5px; border: 1px solid #ddd; }
                h2 { color: #34495e; border-bottom: 1px solid #ecf0f1; padding-bottom: 10px; }
                ul { list-style: disc; padding-left: 20px; }
                li { padding: 8px; border-bottom: 1px solid #f0f0f0; }
                li:last-child { border-bottom: none; }
                .footer { text-align: center; color: #95a5a6; margin-top: 40px; font-style: italic; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>\(escapeHTML(coupleNames))</h1>
                <p class="date">\(escapeHTML(date))</p>
                <p class="location">\(escapeHTML(location))</p>
            </div>
            
            <div class="section">
                <h2>We're Getting Married!</h2>
                <p>We're so excited to celebrate our special day with you!</p>
            </div>
            
            <div class="section">
                <h2>Wedding Details</h2>
                <p><strong>Date:</strong> \(escapeHTML(date))</p>
                <p><strong>Location:</strong> \(escapeHTML(location))</p>
            </div>
            
            <div class="section">
                <h2>Attending Guests</h2>
                <ul>
                \(guestListHTML.isEmpty ? "<li>No guests confirmed yet</li>" : guestListHTML)
                </ul>
            </div>
            
            <div class="footer">
                <p>Created with VowPlanner</p>
            </div>
        </body>
        </html>
        """
    }
    
    private func generateModernTemplate(coupleNames: String, date: String, location: String, guests: [Guest]) -> String {
        let guestListHTML = guests.map { "<li>\(escapeHTML($0.name))</li>" }.joined()
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(coupleNames)) - Wedding</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 20px; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; overflow: hidden; box-shadow: 0 20px 60px rgba(0,0,0,0.3); }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 50px 30px; text-align: center; }
                h1 { font-size: 2.2em; margin-bottom: 10px; }
                .date { font-size: 1.1em; opacity: 0.9; }
                .location { margin-top: 10px; opacity: 0.8; }
                .section { padding: 30px; }
                h2 { color: #667eea; margin-bottom: 15px; font-size: 1.3em; }
                p { color: #555; line-height: 1.6; }
                ul { list-style: none; }
                li { padding: 12px 0; border-bottom: 1px solid #eee; color: #555; }
                li:last-child { border-bottom: none; }
                .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #999; font-size: 0.9em; }
                .tag { display: inline-block; background: #667eea; color: white; padding: 5px 12px; border-radius: 20px; font-size: 0.8em; margin-bottom: 10px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <span class="tag">Wedding Announcement</span>
                    <h1>\(escapeHTML(coupleNames))</h1>
                    <p class="date">📅 \(escapeHTML(date))</p>
                    <p class="location">📍 \(escapeHTML(location))</p>
                </div>
                
                <div class="section">
                    <h2>💍 We're Getting Married!</h2>
                    <p>We're so excited to celebrate our special day with you! Join us as we begin this beautiful journey together.</p>
                </div>
                
                <div class="section">
                    <h2>📋 Wedding Details</h2>
                    <p><strong>Date:</strong> \(escapeHTML(date))</p>
                    <p><strong>Location:</strong> \(escapeHTML(location))</p>
                </div>
                
                <div class="section">
                    <h2>👥 Attending Guests</h2>
                    <ul>
                    \(guestListHTML.isEmpty ? "<li>No guests confirmed yet</li>" : guestListHTML)
                    </ul>
                </div>
                
                <div class="footer">
                    <p>Made with 💜 VowPlanner</p>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    private func generateRomanticTemplate(coupleNames: String, date: String, location: String, guests: [Guest]) -> String {
        let guestListHTML = guests.map { "<li>\(escapeHTML($0.name))</li>" }.joined()
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(coupleNames)) - Wedding</title>
            <style>
                @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Lato:wght@300;400&display=swap');
                body { font-family: 'Lato', sans-serif; background: linear-gradient(to bottom, #fff5f5, #ffe4e8); min-height: 100vh; padding: 20px; }
                .container { max-width: 700px; margin: 0 auto; background: white; border-radius: 20px; overflow: hidden; box-shadow: 0 10px 40px rgba(233, 30, 99, 0.15); }
                .header { background: linear-gradient(to right, #e91e63, #f48fb1); color: white; padding: 60px 40px; text-align: center; position: relative; }
                .header::before { content: '♥'; position: absolute; top: 20px; left: 20px; font-size: 30px; opacity: 0.3; }
                .header::after { content: '♥'; position: absolute; top: 20px; right: 20px; font-size: 30px; opacity: 0.3; }
                h1 { font-family: 'Playfair Display', serif; font-size: 2.8em; margin-bottom: 15px; text-shadow: 2px 2px 4px rgba(0,0,0,0.1); }
                .date { font-size: 1.3em; font-weight: 300; }
                .location { margin-top: 15px; font-style: italic; opacity: 0.9; }
                .section { padding: 35px 40px; }
                h2 { font-family: 'Playfair Display', serif; color: #e91e63; margin-bottom: 20px; font-size: 1.5em; text-align: center; }
                p { color: #666; line-height: 1.8; text-align: center; }
                ul { list-style: none; text-align: center; }
                li { padding: 12px; border-bottom: 1px dashed #ffcdd2; color: #666; }
                li:last-child { border-bottom: none; }
                .footer { background: #fff5f5; padding: 25px; text-align: center; color: #e91e63; }
                .decor { color: #e91e63; font-size: 1.2em; margin: 0 5px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>\(escapeHTML(coupleNames))</h1>
                    <p class="date">\(escapeHTML(date))</p>
                    <p class="location">\(escapeHTML(location))</p>
                </div>
                
                <div class="section">
                    <h2><span class="decor">♦</span> We're Getting Married! <span class="decor">♦</span></h2>
                    <p>With love and joy, we invite you to share in our special day. Your presence means the world to us as we celebrate this beautiful beginning!</p>
                </div>
                
                <div class="section">
                    <h2><span class="decor">♦</span> Wedding Details <span class="decor">♦</span></h2>
                    <p><strong>Date:</strong> \(escapeHTML(date))<br>
                    <strong>Location:</strong> \(escapeHTML(location))</p>
                </div>
                
                <div class="section">
                    <h2><span class="decor">♦</span> Guest List <span class="decor">♦</span></h2>
                    <ul>
                    \(guestListHTML.isEmpty ? "<li>Guest list coming soon</li>" : guestListHTML)
                    </ul>
                </div>
                
                <div class="footer">
                    <p>With love, from VowPlanner <span class="decor">♥</span></p>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    func generateHTML(from data: [String: Any]) -> String {
        let guestList = data["guests"] as? [Guest] ?? []
        let guestListHTML = guestList.map { "<li>\($0.name)</li>" }.joined()

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <title>Our Wedding</title>
        </head>
        <body>
        <h1>Our Wedding</h1>
        <h2>Guests</h2>
        <ul>
        \(guestListHTML)
        </ul>
        </body>
        </html>
        """
    }
}

// MARK: - UI Components

struct ProgressBarView: View {
    var progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().frame(width: geometry.size.width , height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(Color(UIColor.systemTeal))
                
                Rectangle().frame(width: min(CGFloat(self.progress) * geometry.size.width, geometry.size.width) , height: geometry.size.height)
                    .foregroundColor(Color(UIColor.systemBlue))
                    .animation(.linear, value: progress)
            }.cornerRadius(45.0)
        }
    }
}

struct TooltipView: View {
    let message: String
    let key: String
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismiss()
                }
            
            VStack {
                Text(message)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color("AccentColor"))
                    .cornerRadius(8)
                
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.gray.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding()
        }
    }
    
    private func dismiss() {
        appState.tooltipsDismissed.insert(key)
    }
}

// MARK: - Binding Extension

extension Binding {
    init(_ source: Binding<Value?>, default defaultValue: Value) where Value: Equatable {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}
