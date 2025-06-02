import SwiftUI

struct InsightsView: View {
    // Fake sources data
    let sources = [
        Source(title: "Apartment Hunting Tips", type: "article"),
        Source(title: "Budget Planning", type: "note"),
        Source(title: "Neighborhood Research", type: "link")
    ]
    
    // Fake generated content
    let generatedContent = """
    Key Insights for Apartment Search
    
    1. Location Considerations
    • Proximity to public transportation
    • Neighborhood safety ratings
    • Local amenities and services
    
    2. Budget Planning
    • Monthly rent should not exceed 30% of income
    • Additional costs: utilities, insurance, maintenance
    • Emergency fund for unexpected expenses
    
    3. Apartment Features
    • Natural light and ventilation
    • Storage space availability
    • Building amenities and services
    
    4. Moving Timeline
    • Start search 2-3 months before desired move date
    • Schedule viewings during weekdays
    • Prepare all necessary documentation
    """
    
    var body: some View {
        HSplitView {
            // Sources list
            List(sources) { source in
                VStack(alignment: .leading) {
                    Text(source.title)
                        .font(.headline)
                    Text(source.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .frame(minWidth: 200, maxWidth: 300)
            
            // Generated content
            ScrollView {
                Text(generatedContent)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 400)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct Source: Identifiable {
    let id = UUID()
    let title: String
    let type: String
} 