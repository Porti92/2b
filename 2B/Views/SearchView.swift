import SwiftUI
import SVGView
import AppKit

struct SearchView: View {
    @Binding var isVisible: Bool
    var onRequestClose: (() -> Void)? = nil
    var onDropZoneRequest: (() -> Void)? = nil
    @State private var searchText = ""
    @State private var showInsights = false
    @State private var selectedAction: Int? = 1 // Preselect second action for demo
    @State private var isThinking = false
    @State private var showResults = false
    @State private var cardHeight: CGFloat = 60
    @State private var hoveredActionIndex: Int? = nil
    @State private var hoveredMemoryIndex: Int? = nil
    @State private var showSummaryView = false
    @State private var selectedQuickActionTitle: String? = nil
    @State private var gradientStops: [Gradient.Stop] = GlowEffect.generateGradientStops()
    @State private var showResultsContent = false
    @State private var hoveredReferenceIndex: Int? = nil
    @State private var memoryAppear: [Bool] = Array(repeating: false, count: 16)
    @State private var resultsMemoryAppear: [Bool] = Array(repeating: false, count: 16)
    @State private var backButtonHovered = false
    @State private var hoveredMemoryId: UUID? = nil
    @State private var cursorLocation: CGPoint = .zero
    @State private var hoveredMemory: Memory? = nil
    @State private var memoryHoverLocation: CGPoint = .zero
    @State private var isSlashCommand: Bool = false
    @State private var slashCommand: String = ""
    @State private var showSlashOptions = false
    @State private var showMemoryThumbnail = false
    @State private var selectedMemory: Memory? = nil
    @State private var hoveredSlashOption: String? = nil
    
    let slashOptions = [
        (icon: "sparkle", command: "/recent", label: "Recent Memories"),
        (icon: "sparkle", command: "/topics", label: "Topics")
    ]
    
    // Fake quick actions
    let quickActions = [
        QuickAction(icon: "flash.svg", title: "Summarize what I've found"),
        QuickAction(icon: "flash.svg", title: "Create a decision checklist"),
        QuickAction(icon: "flash.svg", title: "Show saved listings and notes"),
        QuickAction(icon: "flash.svg", title: "Extract key considerations")
    ]
    // Fake memory data
    let fakeMemories: [MemorySection] = [
        MemorySection(title: nil, items: [
            Memory(icon: "chrome.svg", title: "Article: How to negotiate rent in Israel – Haaretz.com", date: "35 minutes ago", enabled: true, snippet: "Key tips: Research market rates, be prepared to negotiate, ask for a lower price if paying upfront, inspect thoroughly before signing, document all existing damages...", thumbnail: "/Users/nirportiansky/Documents/Code app/2b/2B/Icons/Figma-Website-2048x1152.webp"),
            Memory(icon: "clipboard-text.svg", title: "Thoughts after seeing the apartment in Florentin", date: "15 April 2025", enabled: true, snippet: "Great location near Rothschild, lots of natural light from south-facing windows. Kitchen needs updating but spacious. Balcony overlooks quiet street. Asking ₪7,500/month...", thumbnail: "/Users/nirportiansky/Documents/Code app/2b/2B/Icons/Figma-Website-2048x1152.webp"),
            Memory(icon: "instagram.svg", title: "Top 10 coffee places in TLV", date: "24 Aug 2024", enabled: true, snippet: "1. Nahat - Best specialty coffee 2. Cafelix - Great work atmosphere 3. Mae Cafe - Instagrammable interior 4. Coffee Bar - Local favorite...", thumbnail: "/Users/nirportiansky/Documents/Code app/2b/2B/Icons/Figma-Website-2048x1152.webp"),
            Memory(icon: "facebook.svg", title: "Light, air flow, access to train, not near clubs", date: "24 Aug 2024", enabled: true, snippet: "Personal apartment requirements: Must have cross-ventilation, prefer top floor or penthouse, walking distance to light rail, avoid Allenby/Dizengoff nightlife area...", thumbnail: ""),
            Memory(icon: "chrome.svg", title: "Bank Hapoalim mortgage calculator", date: "35 minutes ago", enabled: true, snippet: "₪2.85M property: 25% down = ₪712,500. Loan ₪2,137,500 @ 4.5% for 25 years = ~₪11,800/month. Prime rate currently 6.5%. Consider fixed vs variable...", thumbnail: ""),
            Memory(icon: "document-copy.svg", title: "MortgageOptions_2024.pdf", date: "24 Aug 2024", enabled: true, snippet: "Comparison: Fixed rate 4.5% stable payments vs Prime-linked starting 1.5% below prime but fluctuates. Early payment penalties vary. Recommendation: 60% fixed, 40% variable...", thumbnail: "")
        ]),
        MemorySection(title: "Last Month", items: [
            Memory(icon: "clipboard.svg", title: "Tel Aviv vs. Givatayim – pros & cons", date: "24 Aug 2024", enabled: true, snippet: "Tel Aviv: Urban lifestyle, higher prices, better nightlife. Givatayim: Family-friendly, quieter, better schools, 15-20% cheaper, still close to center...", thumbnail: ""),
            Memory(icon: "whatsapp.svg", title: "WhatsApp convo w/ realtor – \"₪2.85M, 3BR w/balcony\"", date: "24 Aug 2024", enabled: true, snippet: "Realtor: Found perfect 3BR in Givatayim, 95sqm + 12sqm balcony, parking included. Near light rail station. Asking ₪2.85M but negotiable. Available for viewing Sunday...", thumbnail: ""),
            Memory(icon: "document-copy.svg", title: "Apartment Budget Planner", date: "24 Aug 2024", enabled: true, snippet: "Total budget: ₪3M max. Preferred: ₪2.8-2.85M to leave renovation buffer. Monthly capacity: ₪12,000 mortgage + ₪2,000 arnona/vaad. Emergency fund: 6 months...", thumbnail: "")
        ])
    ]
    
    var expandedHeight: CGFloat { 404 }
    
    var backgroundView: some View {
        ZStack {
            // Shadow layer
            RoundedRectangle(cornerRadius: 38)
                .fill(Color.clear)
                .shadow(color: Color.black.opacity(0.20), radius: 7.84, x: 0, y: 0)
                .shadow(color: Color.black.opacity(0.25), radius: 1.74, x: 0, y: 0)
            // Card background and content
            ZStack {
                VisualEffectBlur(radius: 34.84)
                Color(red: 246/255, green: 246/255, blue: 246/255).opacity(0.84)
                Color(red: 38/255, green: 38/255, blue: 38/255).opacity(0.10)
            }
            .cornerRadius(38)
            .overlay(
                RoundedRectangle(cornerRadius: 38)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .blur(radius: 0.87)
            )
        }
    }
    
    var expandedContentView: some View {
        ZStack {
            backgroundView // Card background is now inside the expanded card
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: { showSummaryView = false }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(backButtonHovered ? 0.08 : 0.05))
                            .clipShape(Circle())
                            .scaleEffect(backButtonHovered ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: backButtonHovered)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                    .onHover { hovering in
                        backButtonHovered = hovering
                    }
                    Spacer()
                    HStack(spacing: 11.49) {
                        if let iconURL = Bundle.main.url(forResource: "2bicon", withExtension: "pdf", subdirectory: nil),
                           let nsImage = NSImage(contentsOf: iconURL) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .frame(width: 22, height: 22)
                        }
                        Text(searchText.isEmpty ? (selectedQuickActionTitle ?? "Quick Action") : searchText)
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundColor(.primary)
                        Text(Date(), style: .time)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Color.clear
                        .frame(width: 32, height: 32)
                        .padding(.trailing, 16)
                }
                .frame(height: 37.45)
                .background(Color.black.opacity(0.03))
                // Gap between top bar and content
                Spacer().frame(height: 24)
                // Main content
                HStack(alignment: .top, spacing: 48) {
                    // Left: Memory list
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Recent memories")
                            .font(.custom("SF Pro Display", size: 13.4).weight(.medium))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if showSummaryView {
                            ForEach(fakeMemories) { section in
                                if let title = section.title {
                                    Text(title)
                                        .font(.custom("SF Pro Display", size: 13.4).weight(.regular))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 16)
                                        .padding(.bottom, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                VStack(spacing: 10) {
                                    ForEach(section.items.indices, id: \ .self) { idx in
                                        let memory = section.items[idx]
                                        let globalIdx = fakeMemories.prefix { $0.id != section.id }.reduce(0) { $0 + $1.items.count } + idx
                                        MemoryResultRow(
                                            memory: memory,
                                            isHovered: true // Always show hover state in summary view
                                        )
                                        .onHover { hovering in
                                            print("Memory row hover: \(hovering) for \(memory.title)")
                                            if !hovering {
                                                hoveredMemoryId = nil
                                                hoveredMemory = nil
                                            }
                                        }
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear
                                                    .onContinuousHover { phase in
                                                        switch phase {
                                                        case .active(let location):
                                                            hoveredMemoryId = memory.id
                                                            hoveredMemory = memory
                                                            let frame = geo.frame(in: .global)
                                                            memoryHoverLocation = CGPoint(
                                                                x: frame.minX + location.x,
                                                                y: frame.minY + location.y
                                                            )
                                                            print("Hovering at: \(memoryHoverLocation)")
                                                        case .ended:
                                                            hoveredMemoryId = nil
                                                            hoveredMemory = nil
                                                        }
                                                    }
                                            }
                                        )
                                        .zIndex(hoveredMemoryId == memory.id ? 100 : 0)
                                        .opacity(memoryAppear[globalIdx] ? 1 : 0)
                                        .offset(y: memoryAppear[globalIdx] ? 0 : 10)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(globalIdx) * 0.05), value: memoryAppear[globalIdx])
                                    }
                                }
                            }
                            .onAppear {
                                // Animate each memory item in sequence
                                for i in memoryAppear.indices {
                                    memoryAppear[i] = false
                                }
                                for i in memoryAppear.indices {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.05) {
                                        memoryAppear[i] = true
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .frame(width: 436.56)
                    // Right: Summary content
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Apartment Search Summary")
                                .font(.custom("SF Pro Display", size: 13.4).weight(.medium))
                            Spacer()
                        }
                        .padding(.top, 0)
                        .padding(.horizontal, 0)
                        HStack(spacing: 8) {
                            Text("16 resources")
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 0)
                        .padding(.bottom, 12)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                Spacer().frame(height: 24) // 24px gap between top bar and main content
                                AnimatedSummaryText(
                                    summary: "You've been exploring apartments primarily in Tel Aviv and Givatayim, focusing on areas with good light, low noise, and easy access to public transport. You've compared neighborhoods based on lifestyle fit, budget, and long-term value.\n\nYour budget is approximately ₪2.85M, and you're looking for a 3-bedroom apartment with outdoor space. You've shown interest in properties in Florentin (central, more urban feel) and Givatayim (quieter, more family-friendly).\n\nYou've saved key mortgage documents comparing fixed vs. prime-linked loans, and used Bank Hapoalim's calculator to test monthly scenarios. You've also reviewed local tips on rent negotiation strategies and noted down personal must-haves like natural light, proximity to trains, and avoiding nightlife areas."
                                )
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.primary)
                                .padding(.bottom, 16)
                                HStack(spacing: 4) {
                                    Button(action: { /* Regenerate action */ }) {
                                        if let iconURL = Bundle.main.url(forResource: "repeat-arrow", withExtension: "svg", subdirectory: nil) {
                                            SVGView(contentsOf: iconURL)
                                                .frame(width: 16, height: 16)
                                                .foregroundColor(.black)
                                                .opacity(0.85)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    Button(action: { /* Copy action */ }) {
                                        if let iconURL = Bundle.main.url(forResource: "clipboard", withExtension: "svg", subdirectory: nil) {
                                            SVGView(contentsOf: iconURL)
                                                .frame(width: 16, height: 16)
                                                .foregroundColor(.black)
                                                .opacity(0.85)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    Button(action: { /* Dislike action */ }) {
                                        if let iconURL = Bundle.main.url(forResource: "dislike", withExtension: "svg", subdirectory: nil) {
                                            SVGView(contentsOf: iconURL)
                                                .frame(width: 16, height: 16)
                                                .foregroundColor(.black)
                                                .opacity(0.85)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    Button(action: { /* Like action */ }) {
                                        if let iconURL = Bundle.main.url(forResource: "like-1", withExtension: "svg", subdirectory: nil) {
                                            SVGView(contentsOf: iconURL)
                                                .frame(width: 16, height: 16)
                                                .foregroundColor(.black)
                                                .opacity(0.85)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    Button(action: { /* Menu/send action */ }) {
                                        if let iconURL = Bundle.main.url(forResource: "send-2", withExtension: "svg", subdirectory: nil) {
                                            SVGView(contentsOf: iconURL)
                                                .frame(width: 16, height: 16)
                                                .foregroundColor(.black)
                                                .opacity(0.85)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                                .opacity(showSummaryView ? 1 : 0)
                                .offset(y: showSummaryView ? 0 : 10)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: showSummaryView)
                            }
                            .padding(.bottom, 32)
                        }
                    }
                    .frame(width: 448.05)
                    .background(Color.white.opacity(0.04))
                }
                .padding(47.87)
            }
        }
        .overlay(
            // Tooltip overlay - renders on top of everything
            GeometryReader { geo in
                if let memory = hoveredMemory {
                    MemoryTooltipView(memory: memory)
                        .position(
                            x: memoryHoverLocation.x - geo.frame(in: .global).minX + 150,
                            y: memoryHoverLocation.y - geo.frame(in: .global).minY
                        )
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: memoryHoverLocation)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
        )
    }
    
    var searchContentView: some View {
        ZStack {
            backgroundView // Card background is now inside the same container
            VStack(spacing: 0) {
                // Search bar
                ZStack {
                    // Glow effect: always present, just fades in/out
                    ZStack {
                        EffectNoBlur(gradientStops: gradientStops, width: 5)
                        Effect(gradientStops: gradientStops, width: 7, blur: 4)
                    }
                    .frame(width: 596, height: 60)
                    .cornerRadius(38)
                    .opacity(isThinking ? 1 : 0)
                    .scaleEffect(isThinking ? 1.0 : 0.9)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isThinking)
                    .allowsHitTesting(false)
                    // Search bar content
                    HStack(spacing: 6.45) {
                        // 2bicon (with glow if isThinking) ONLY here
                        if let iconURL = Bundle.main.url(forResource: "2bicon", withExtension: "pdf", subdirectory: nil),
                           let nsImage = NSImage(contentsOf: iconURL) {
                            if isThinking {
                                ColorShiftingGlowIcon(nsImage: nsImage)
                                    .frame(width: 28, height: 28)
                                    .padding(.trailing, 8)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .padding(.trailing, 8)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        
                        CustomPlainTextField(
                            placeholder: searchText.isEmpty && !showSlashOptions ? "What's on your mind?" : "Type a command or search...", 
                            text: $searchText, 
                            focusOnAppear: true, 
                            onCommit: {
                                handleSearchCommit()
                            }
                        )
                        .font(.system(size: 24, weight: .light, design: .default))
                        .disableAutocorrection(true)
                        
                        // Show CMD+F when slash is typed
                        if showSlashOptions {
                            Text("⌘ + F")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.horizontal, 22.25)
                    .padding(.vertical, 16.13)
                    .frame(width: 596, height: 60)
                }
                
                // Slash options menu
                if showSlashOptions {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        Text("Quick brain actions")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 12)
                        
                        // Options
                        VStack(spacing: 4) {
                            ForEach(slashOptions, id: \.command) { option in
                                Button(action: {
                                    handleSlashCommand(option.command)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: option.icon)
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                            .frame(width: 24, height: 24)
                                        
                                        Text(option.label)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        hoveredSlashOption == option.command ? 
                                        Color.gray.opacity(0.1) : Color.clear
                                    )
                                    .cornerRadius(8)
                                    .padding(.horizontal, 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onHover { hovering in
                                    hoveredSlashOption = hovering ? option.command : nil
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }
                
                // Memory thumbnail view
                else if showMemoryThumbnail, let memory = selectedMemory {
                    VStack(spacing: 0) {
                        MemoryThumbnailView(memory: memory)
                            .padding(20)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }
                }
                
                // Results content (existing code)
                else if !isThinking && showResults && !searchText.isEmpty && showResultsContent {
                    Divider().padding(.top, 8)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Quick Actions
                            Text("Quick brain actions")
                                .font(.system(size: 12, weight: .light, design: .default))
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                                .padding(.horizontal, 16)
                            VStack(spacing: 10) {
                                ForEach(quickActions.indices, id: \.self) { idx in
                                    let action = quickActions[idx]
                                    QuickActionRow(
                                        action: action,
                                        isHovered: hoveredActionIndex == idx
                                    )
                                    .onHover { hovering in
                                        hoveredActionIndex = hovering ? idx : nil
                                    }
                                    .onTapGesture {
                                        selectedQuickActionTitle = action.title
                                        // Add haptic feedback if available
                                        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                                        showSummaryView = true
                                    }
                                    .opacity(showResultsContent ? 1 : 0)
                                    .offset(y: showResultsContent ? 0 : 20)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(idx) * 0.05), value: showResultsContent)
                                }
                            }
                            .padding(.bottom, 8)
                            Divider().padding(.vertical, 8)
                            // Memories
                            Text("Relevant memories")
                                .font(.system(size: 12, weight: .light, design: .default))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 8)
                                .padding(.horizontal, 16)
                            VStack(spacing: 0) {
                                ForEach(fakeMemories) { section in
                                    if let title = section.title {
                                        Text(title)
                                            .font(.system(size: 12, weight: .light, design: .default))
                                            .foregroundColor(.secondary)
                                            .padding(.top, 16)
                                            .padding(.bottom, 8)
                                            .padding(.horizontal, 16)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    VStack(spacing: 10) {
                                        ForEach(section.items.indices, id: \.self) { idx in
                                            let memory = section.items[idx]
                                            let globalIdx = fakeMemories.prefix { $0.id != section.id }.reduce(0) { $0 + $1.items.count } + idx
                                            MemoryResultRow(
                                                memory: memory,
                                                isHovered: hoveredMemoryIndex == idx
                                            )
                                            .onHover { hovering in
                                                print("Memory row hover: \(hovering) for \(memory.title)")
                                                if !hovering {
                                                    hoveredMemoryId = nil
                                                    hoveredMemory = nil
                                                }
                                            }
                                            .opacity(resultsMemoryAppear[globalIdx] ? 1 : 0)
                                            .offset(y: resultsMemoryAppear[globalIdx] ? 0 : 10)
                                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(globalIdx) * 0.05), value: resultsMemoryAppear[globalIdx])
                                        }
                                    }
                                }
                            }
                            .onAppear {
                                // Animate each memory item in sequence
                                for i in resultsMemoryAppear.indices {
                                    resultsMemoryAppear[i] = false
                                }
                                for i in resultsMemoryAppear.indices {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.05) {
                                        resultsMemoryAppear[i] = true
                                    }
                                }
                            }
                            Spacer(minLength: 8)
                        }
                    }
                    .padding(.top, 0)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showResultsContent)
                } else if !isThinking && showResults && !searchText.isEmpty {
                    Spacer()
                }
            }
            .padding(0)
            .sheet(isPresented: $showInsights) {
                InsightsView()
            }
        }
    }
    
    var body: some View {
        ZStack {
            if showSummaryView {
                expandedContentView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 1.05, anchor: .center)
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.95, anchor: .center)
                            .combined(with: .opacity)
                    ))
            } else {
                searchContentView
                    .frame(
                        width: 596, 
                        height: showSlashOptions ? 240 : 
                               (showMemoryThumbnail ? 480 : 
                               (showResults ? 340 : 60))
                    )
                    .animation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.2), value: showSlashOptions)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.2), value: showMemoryThumbnail)
                    .blur(radius: showSummaryView ? 10 : 0)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(
            width: showSummaryView ? 1010.99 : 596, 
            height: showSummaryView ? 585 : 
                   (showSlashOptions ? 240 : 
                   (showMemoryThumbnail ? 480 :
                   (showResults ? expandedHeight : 60)))
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.88, blendDuration: 0.2), value: showSummaryView)
        .onChange(of: showResults) { _, newValue in
            if newValue && !showSummaryView && !showMemoryThumbnail {
                // Notify window to expand from top
                NotificationCenter.default.post(
                    name: NSNotification.Name("SecondBrain.RecenterWindow"),
                    object: nil,
                    userInfo: ["width": 596, "height": expandedHeight]
                )
            } else if !newValue && !showSummaryView && !showMemoryThumbnail && !showSlashOptions {
                // Notify window to recenter
                NotificationCenter.default.post(
                    name: NSNotification.Name("SecondBrain.RecenterWindow"),
                    object: nil,
                    userInfo: ["width": 596, "height": 60]
                )
            }
        }
        .onChange(of: showMemoryThumbnail) { _, newValue in
            if newValue {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SecondBrain.RecenterWindow"),
                    object: nil,
                    userInfo: ["width": 596, "height": 480]
                )
            }
        }
        .onChange(of: showSlashOptions) { _, newValue in
            if newValue {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SecondBrain.RecenterWindow"),
                    object: nil,
                    userInfo: ["width": 596, "height": 240]
                )
            }
        }
        .background(KeyEventHandlingView(onEscape: {
            onRequestClose?()
        }))
        .onChange(of: searchText) { _, newValue in
            showSlashOptions = (newValue == "/")
            if searchText.isEmpty {
                showResults = false
                isThinking = false
                showResultsContent = false
                showMemoryThumbnail = false
                selectedMemory = nil
                // Reset results memory animations
                for i in resultsMemoryAppear.indices {
                    resultsMemoryAppear[i] = false
                }
            }
        }
        .onChange(of: showResultsContent) { _, newValue in
            if !newValue {
                // Reset results memory animations when hiding
                for i in resultsMemoryAppear.indices {
                    resultsMemoryAppear[i] = false
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            showSlashOptions = (newValue == "/")
        }
    }
    
    private var summaryParts: [HighlightedSummaryPart] {
        [
            .init(text: "You've been exploring apartments primarily in Tel Aviv and Givatayim", memoryIndex: 0),
            .init(text: ", focusing on areas with good light, low noise, and easy access to public transport.", memoryIndex: 1),
            .init(text: " You've compared neighborhoods based on lifestyle fit, budget, and long-term value.", memoryIndex: 2),
            .init(text: "\n\nYour budget is approximately ₪2.85M, and you're looking for a 3-bedroom apartment with outdoor space.", memoryIndex: 3),
            .init(text: " You've shown interest in properties in Florentin (central, more urban feel) and Givatayim (quieter, more family-friendly).", memoryIndex: 4),
            .init(text: "\n\nYou've saved key mortgage documents comparing fixed vs. prime-linked loans, and used Bank Hapoalim's calculator to test monthly scenarios.", memoryIndex: 5),
            .init(text: " You've also reviewed local tips on rent negotiation strategies and noted down personal must-haves like natural light, proximity to trains, and avoiding nightlife areas.", memoryIndex: 6)
        ]
    }
    
    private func attributedSummary(hoveredPhraseIndex: Int?) -> AttributedString {
        let phrases = [
            "You've been exploring apartments primarily in Tel Aviv and Givatayim",
            ", focusing on areas with good light, low noise, and easy access to public transport.",
            " You've compared neighborhoods based on lifestyle fit, budget, and long-term value.",
            "\n\nYour budget is approximately ₪2.85M, and you're looking for a 3-bedroom apartment with outdoor space.",
            " You've shown interest in properties in Florentin (central, more urban feel) and Givatayim (quieter, more family-friendly).",
            "\n\nYou've saved key mortgage documents comparing fixed vs. prime-linked loans, and used Bank Hapoalim's calculator to test monthly scenarios.",
            " You've also reviewed local tips on rent negotiation strategies and noted down personal must-haves like natural light, proximity to trains, and avoiding nightlife areas."
        ]
        var result = AttributedString("")
        for (idx, phrase) in phrases.enumerated() {
            var attr = AttributedString(phrase)
            if hoveredPhraseIndex == idx {
                attr.backgroundColor = .yellow.opacity(0.4)
            }
            result += attr
        }
        return result
    }
    
    private func handleSearchCommit() {
        if !searchText.isEmpty {
            // Check for drop zone command
            if searchText == "/dropzone" {
                onDropZoneRequest?()
                searchText = ""
                return
            }
            
            // Check if it's a slash command selection
            if searchText.starts(with: "/") {
                return // Don't process slash commands as searches
            }
            
            // Otherwise, process as a memory search
            isThinking = true
            showResults = false
            showMemoryThumbnail = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isThinking = false
                
                // For demo: show memory thumbnail for specific searches
                if searchText.lowercased().contains("coffee") || searchText.lowercased().contains("grinder") {
                    selectedMemory = Memory(
                        icon: "instagram.svg",
                        title: "Coffee Grinder",
                        date: "April 27 2025",
                        enabled: true,
                        snippet: "פוסט מהמחלבה החדשה הזאת שמעתיהת של המחנת במנת על המחלבה הזאת שמעתי וכן אגב 12 גרמים כיחוד המנה hamillonbeach.co.il",
                        thumbnail: "coffee-grinder-instagram"
                    )
                    showMemoryThumbnail = true
                } else {
                    // Show regular results
                    showResults = true
                    showResultsContent = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showResultsContent = true
                    }
                }
            }
        }
    }
    
    private func handleSlashCommand(_ command: String) {
        searchText = command
        showSlashOptions = false
        
        if command == "/recent" {
            // Show recent memories results
            isThinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isThinking = false
                showResults = true
                showResultsContent = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showResultsContent = true
                }
            }
        }
    }
}

struct ColorShiftingGlowIcon: View {
    let nsImage: NSImage
    @State private var animate = false
    let colors: [Color] = [
        Color(hex: "1DE9B6"), // vivid turquoise
        Color(hex: "00B8D4"), // turquoise blue
        Color(hex: "00E5FF"), // light cyan
        Color(hex: "64FFDA"), // aqua
        Color(hex: "18FFFF"), // bright aqua
        Color(hex: "00C9A7"), // teal turquoise
        Color(hex: "43E8D8")  // soft turquoise
    ]
    var body: some View {
        ZStack {
            AngularGradient(gradient: Gradient(colors: colors), center: .center, angle: .degrees(animate ? 360 : 0))
                .blur(radius: 10)
                .frame(width: 40, height: 40)
                .opacity(0.32)
                .animation(.linear(duration: 2.8).repeatForever(autoreverses: false), value: animate)
            Image(nsImage: nsImage)
                .resizable()
                .frame(width: 28, height: 28)
        }
        .onAppear { animate = true }
    }
}

// Key event handler for Escape
struct KeyEventHandlingView: NSViewRepresentable {
    var onEscape: () -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSEventCatcher()
        view.onEscape = onEscape
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    class NSEventCatcher: NSView {
        var onEscape: (() -> Void)?
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { // Escape
                onEscape?()
            }
        }
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            window?.makeFirstResponder(self)
        }
    }
}

struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
}

struct QuickActionRow: View {
    let action: QuickAction
    let isHovered: Bool
    var body: some View {
        HStack(spacing: 10) {
            if let iconURL = Bundle.main.url(forResource: action.icon.replacingOccurrences(of: ".svg", with: ""), withExtension: "svg", subdirectory: nil) {
                SVGView(contentsOf: iconURL)
                    .frame(width: 18, height: 18)
                    .foregroundColor(.black)
                    .opacity(0.85)
                    .padding(.trailing, 2)
            }
            Text(action.title)
                .font(.system(size: 12, weight: .light, design: .default))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 32)
        .background(
            (isHovered ? Color.gray.opacity(0.13) : Color.clear)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        )
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}

struct MemorySection: Identifiable {
    let id = UUID()
    let title: String?
    let items: [Memory]
}

struct Memory: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let date: String
    let enabled: Bool
    let snippet: String
    let thumbnail: String // Path or name of the thumbnail image
}

struct MemoryResultRow: View {
    let memory: Memory
    let isHovered: Bool
    var body: some View {
        HStack(spacing: 10) {
            if let iconURL = Bundle.main.url(forResource: memory.icon.replacingOccurrences(of: ".svg", with: ""), withExtension: "svg", subdirectory: nil) {
                SVGView(contentsOf: iconURL)
                    .frame(width: 18, height: 18)
                    .foregroundColor(.black)
                    .opacity(memory.enabled ? 0.85 : 0.34)
            }
            Text(memory.title)
                .font(.system(size: 12, weight: .light, design: .default))
                .foregroundColor(memory.enabled ? .primary : .gray)
                .opacity(memory.enabled ? 1 : 0.4)
                .lineLimit(1)
            Spacer()
            Text(memory.date)
                .font(.system(size: 12, weight: .light, design: .default))
                .foregroundColor(.gray)
                .opacity(memory.enabled ? 1 : 0.4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 32)
        .background(
            (isHovered ? Color.gray.opacity(0.13) : Color.clear)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        )
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}

// VisualEffectBlur for soft background
struct VisualEffectBlur: NSViewRepresentable {
    var radius: CGFloat = 34.84
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 38
        // view.layer?.masksToBounds = true // Removed to allow drop shadow
        // Custom blur radius is not natively supported, but this sets up the effect
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// Custom plain text field with no background or focus ring
struct CustomPlainTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String
    var focusOnAppear: Bool = false
    var onCommit: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 24, weight: .light)
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.commit)
        textField.stringValue = text
        if focusOnAppear && !context.coordinator.didFocus {
            DispatchQueue.main.async {
                textField.window?.makeFirstResponder(textField)
                context.coordinator.didFocus = true
            }
        }
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if the field is not first responder and the value is out of sync
        if let window = nsView.window, window.firstResponder !== nsView, nsView.stringValue != text {
            nsView.stringValue = text
        }
        // Do NOT set first responder here!
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomPlainTextField
        var didFocus = false
        init(_ parent: CustomPlainTextField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        @objc func commit() {
            parent.onCommit()
        }
    }
}

struct ShimmerTypewriterRenderer: TextRenderer {
    var shimmerPosition: Double
    var typewriterProgress: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(shimmerPosition, typewriterProgress) }
        set {
            shimmerPosition = newValue.first
            typewriterProgress = newValue.second
        }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let shimmerWidth: Double = 40
        var glyphIndex = 0
        for line in layout {
            for run in line {
                for glyph in run {
                    let appear = Double(glyphIndex) < typewriterProgress
                    let fade = min(max(typewriterProgress - Double(glyphIndex), 0), 1)
                    let glyphX = glyph.typographicBounds.rect.midX
                    let shimmer = max(0, 1 - abs(glyphX - shimmerPosition) / shimmerWidth)
                    var copy = context
                    copy.opacity = appear ? (0.5 + 0.5 * fade + 0.5 * shimmer) : 0
                    copy.draw(glyph, options: .disablesSubpixelQuantization)
                    glyphIndex += 1
                }
            }
        }
    }
}

struct AnimatedSummaryText: View {
    @State private var shimmerPosition = 0.0
    @State private var typewriterProgress = 0.0
    let summary: String

    var body: some View {
        if #available(macOS 15.0, *) {
            Text(summary)
                .font(.system(size: 13.4, weight: .regular))
                .textRenderer(
                    ShimmerTypewriterRenderer(
                        shimmerPosition: shimmerPosition,
                        typewriterProgress: typewriterProgress
                    )
                )
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                            shimmerPosition = 600 // Adjust based on text width
                        }
                        withAnimation(.spring(response: 2.0, dampingFraction: 1.0)) {
                            typewriterProgress = Double(summary.count)
                        }
                    }
                }
        } else {
            Text(summary)
                .font(.system(size: 13.4, weight: .regular))
        }
    }
}

struct MinimalWaveRenderer: TextRenderer {
    var strength: Double
    var animatableData: Double {
        get { strength }
        set { strength = newValue }
    }
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                for (index, glyph) in run.enumerated() {
                    var copy = context
                    let yOffset = strength * sin(Double(index) * 0.5)
                    copy.translateBy(x: 0, y: yOffset)
                    copy.draw(glyph, options: .disablesSubpixelQuantization)
                }
            }
        }
    }
}

struct MinimalAnimatedSummaryText: View {
    @State private var waveAmount = -10.0
    let summary: String
    let startAnimation: Bool

    var body: some View {
        if #available(macOS 15.0, *) {
            Text(summary)
                .font(.system(size: 13.4, weight: .regular))
                .textRenderer(MinimalWaveRenderer(strength: waveAmount))
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        waveAmount = 10
                    }
                }
        } else {
            Text(summary)
                .font(.system(size: 13.4, weight: .regular))
        }
    }
}

struct HighlightedSummaryPart {
    let text: String
    let memoryIndex: Int
}

struct SummaryPartView: View {
    let part: HighlightedSummaryPart
    @Binding var hoveredMemoryIndex: Int?
    var body: some View {
        Text(part.text)
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.primary)
            .background(
                hoveredMemoryIndex == part.memoryIndex ?
                    RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.4)) : nil
            )
            .onHover { hovering in
                hoveredMemoryIndex = hovering ? part.memoryIndex : nil
            }
    }
}

struct MemoryTooltipView: View {
    let memory: Memory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with icon and title
            HStack(spacing: 8) {
                if let iconURL = Bundle.main.url(forResource: memory.icon.replacingOccurrences(of: ".svg", with: ""), withExtension: "svg", subdirectory: nil) {
                    SVGView(contentsOf: iconURL)
                        .frame(width: 16, height: 16)
                        .foregroundColor(.black)
                        .opacity(0.7)
                }
                Text(memory.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            // Snippet content
            Text(memory.snippet)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // Date
            Text(memory.date)
                .font(.system(size: 9, weight: .light))
                .foregroundColor(.gray.opacity(0.6))
        }
        .padding(12)
        .frame(width: 280)
        .background(
            Color.yellow  // Temporary bright color for debugging
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
    }
}

struct MemoryThumbnailView: View {
    let memory: Memory
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Instagram icon
                if let iconURL = Bundle.main.url(forResource: memory.icon.replacingOccurrences(of: ".svg", with: ""), withExtension: "svg", subdirectory: nil) {
                    SVGView(contentsOf: iconURL)
                        .frame(width: 32, height: 32)
                        .foregroundColor(.black)
                }
                
                // Title
                Text(memory.title)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Date
                Text(memory.date)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Instagram post mockup
            VStack(spacing: 0) {
                // Post header
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("shaoulian.il and hamiltonbeach.israel")
                            .font(.system(size: 13, weight: .medium))
                        Text("Hamilton beach")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Image placeholder
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.5, blue: 0.3),
                                    Color(red: 1.0, green: 0.3, blue: 0.5),
                                    Color(red: 0.8, green: 0.2, blue: 0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Coffee grinder image placeholder
                    VStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Coffee Grinder")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .frame(height: 240)
                
                // Post actions
                HStack(spacing: 16) {
                    Image(systemName: "heart")
                        .font(.system(size: 22))
                    Image(systemName: "message")
                        .font(.system(size: 22))
                    Image(systemName: "paperplane")
                        .font(.system(size: 22))
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 22))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Post content
                VStack(alignment: .leading, spacing: 8) {
                    Text("20 likes")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Text(memory.snippet)
                        .font(.system(size: 13, weight: .regular))
                        .lineLimit(3)
                        .foregroundColor(.primary.opacity(0.9))
                    
                    Text("December 12, 2024")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity)
    }
} 