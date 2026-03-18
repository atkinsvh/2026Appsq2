import Foundation

extension Array where Element == Guest {
    func generateCSV() -> String {
        var csvString = "Name,Email,Phone,Side,RSVP Status,Party Size,Meal Choice,Dietary Notes,Household\n"
        
        for guest in self {
            let name = guest.name.replacingOccurrences(of: ",", with: " ")
            let email = guest.email?.replacingOccurrences(of: ",", with: " ") ?? ""
            let phone = guest.phone?.replacingOccurrences(of: ",", with: " ") ?? ""
            let side = guest.side.rawValue
            let rsvp = guest.rsvpStatus.rawValue
            let partySize = "\(guest.partySize)"
            let meal = guest.mealChoice?.replacingOccurrences(of: ",", with: " ") ?? ""
            let dietary = guest.dietaryNotes?.replacingOccurrences(of: ",", with: " ") ?? ""
            let household = guest.household?.replacingOccurrences(of: ",", with: " ") ?? ""
            
            let row = "\(name),\(email),\(phone),\(side),\(rsvp),\(partySize),\(meal),\(dietary),\(household)\n"
            csvString.append(row)
        }
        
        return csvString
    }
}
