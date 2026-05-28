// **Note**: This item view model is to display data and does not contain any domain model to prevent views accessing it

import Foundation

struct MoviesListItemViewModel: Equatable {
    var id: String
    let title: String
    let overview: String
    let releaseDate: String
    let posterImagePath: String?
    let isFavorite: Bool
}

extension MoviesListItemViewModel {

    init(movie: Movie, isFavorite: Bool = false) {
        self.id = movie.id
        self.title = movie.title ?? ""
        self.posterImagePath = movie.posterPath
        self.overview = movie.overview ?? ""
        self.isFavorite = isFavorite
        if let releaseDate = movie.releaseDate {
            self.releaseDate = "\(NSLocalizedString("Release Date", comment: "")): \(dateFormatter.string(from: releaseDate))"
        } else {
            self.releaseDate = NSLocalizedString("To be announced", comment: "")
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()
