import Foundation

struct MoviesListViewModelActions {
    /// Note: if you would need to edit movie inside Details screen and update this Movies List screen with updated movie then you would need this closure:
    /// showMovieDetails: (Movie, @escaping (_ updated: Movie) -> Void) -> Void
    let showMovieDetails: (Movie) -> Void
    let showMovieQueriesSuggestions: (@escaping (_ didSelect: MovieQuery) -> Void) -> Void
    let closeMovieQueriesSuggestions: () -> Void
}

enum MoviesListViewModelLoading {
    case fullScreen
    case nextPage
}

protocol MoviesListViewModelInput {
    func viewDidLoad()
    func didLoadNextPage()
    func didSearch(query: String)
    func didCancelSearch()
    func showQueriesSuggestions()
    func closeQueriesSuggestions()
    func didSelectItem(at index: Int)
    func didToggleFavorite(at index: Int)
    func didToggleFavoritesFilter()
}

protocol MoviesListViewModelOutput {
    var items: Observable<[MoviesListItemViewModel]> { get } /// Also we can calculate view model items on demand:  https://github.com/kudoleh/iOS-Clean-Architecture-MVVM/pull/10/files
    var loading: Observable<MoviesListViewModelLoading?> { get }
    var query: Observable<String> { get }
    var error: Observable<String> { get }
    var favoriteFilterActive: Observable<Bool> { get }
    var isEmpty: Bool { get }
    var screenTitle: String { get }
    var emptyDataTitle: String { get }
    var errorTitle: String { get }
    var searchBarPlaceholder: String { get }
}

typealias MoviesListViewModel = MoviesListViewModelInput & MoviesListViewModelOutput

final class DefaultMoviesListViewModel: MoviesListViewModel {

    private let searchMoviesUseCase: SearchMoviesUseCase
    private let actions: MoviesListViewModelActions?

    var currentPage: Int = 0
    var totalPageCount: Int = 1
    var hasMorePages: Bool { currentPage < totalPageCount }
    var nextPage: Int { hasMorePages ? currentPage + 1 : currentPage }

    private var pages: [MoviesPage] = []
    private var favoriteMovieIDs: Set<Movie.Identifier> = []
    private var isFavoritesFilterActive = false
    private var moviesLoadTask: Cancellable? { willSet { moviesLoadTask?.cancel() } }
    private let mainQueue: DispatchQueueType

    // MARK: - OUTPUT

    let items: Observable<[MoviesListItemViewModel]> = Observable([])
    let loading: Observable<MoviesListViewModelLoading?> = Observable(.none)
    let query: Observable<String> = Observable("")
    let error: Observable<String> = Observable("")
    let favoriteFilterActive: Observable<Bool> = Observable(false)
    var isEmpty: Bool { return items.value.isEmpty }
    let screenTitle = NSLocalizedString("Movies", comment: "")
    let emptyDataTitle = NSLocalizedString("Search results", comment: "")
    let errorTitle = NSLocalizedString("Error", comment: "")
    let searchBarPlaceholder = NSLocalizedString("Search Movies", comment: "")

    // MARK: - Init
    
    init(
        searchMoviesUseCase: SearchMoviesUseCase,
        actions: MoviesListViewModelActions? = nil,
        mainQueue: DispatchQueueType = DispatchQueue.main
    ) {
        self.searchMoviesUseCase = searchMoviesUseCase
        self.actions = actions
        self.mainQueue = mainQueue
    }

    // MARK: - Private

    private func appendPage(_ moviesPage: MoviesPage) {
        currentPage = moviesPage.page
        totalPageCount = moviesPage.totalPages

        pages = pages
            .filter { $0.page != moviesPage.page }
            + [moviesPage]

        rebuildItems()
    }

    private func resetPages() {
        currentPage = 0
        totalPageCount = 1
        pages.removeAll()
        items.value.removeAll()
    }

    private var displayedMovies: [Movie] {
        let movies = pages.movies
        guard isFavoritesFilterActive else { return movies }
        return movies.filter { favoriteMovieIDs.contains($0.id) }
    }

    private func rebuildItems() {
        items.value = displayedMovies.map {
            MoviesListItemViewModel(
                movie: $0,
                isFavorite: favoriteMovieIDs.contains($0.id)
            )
        }
    }

    private func deactivateFavoritesFilter() {
        guard isFavoritesFilterActive else { return }
        isFavoritesFilterActive = false
        favoriteFilterActive.value = false
    }

    private func load(movieQuery: MovieQuery, loading: MoviesListViewModelLoading) {
        self.loading.value = loading
        query.value = movieQuery.query

        moviesLoadTask = searchMoviesUseCase.execute(
            requestValue: .init(query: movieQuery, page: nextPage),
            cached: { [weak self] page in
                self?.mainQueue.async {
                    self?.appendPage(page)
                }
            },
            completion: { [weak self] result in
                self?.mainQueue.async {
                    switch result {
                    case .success(let page):
                        self?.appendPage(page)
                    case .failure(let error):
                        self?.handle(error: error)
                    }
                    self?.loading.value = .none
                }
        })
    }

    private func handle(error: Error) {
        self.error.value = error.isInternetConnectionError ?
            NSLocalizedString("No internet connection", comment: "") :
            NSLocalizedString("Failed loading movies", comment: "")
    }

    private func update(movieQuery: MovieQuery) {
        deactivateFavoritesFilter()
        resetPages()
        load(movieQuery: movieQuery, loading: .fullScreen)
    }
}

// MARK: - INPUT. View event methods

extension DefaultMoviesListViewModel {

    func viewDidLoad() { }

    func didLoadNextPage() {
        guard !isFavoritesFilterActive, hasMorePages, loading.value == .none else { return }
        load(movieQuery: .init(query: query.value),
             loading: .nextPage)
    }

    func didSearch(query: String) {
        guard !query.isEmpty else { return }
        update(movieQuery: MovieQuery(query: query))
    }

    func didCancelSearch() {
        moviesLoadTask?.cancel()
    }

    func showQueriesSuggestions() {
        actions?.showMovieQueriesSuggestions(update(movieQuery:))
    }

    func closeQueriesSuggestions() {
        actions?.closeMovieQueriesSuggestions()
    }

    func didSelectItem(at index: Int) {
        actions?.showMovieDetails(displayedMovies[index])
    }

    func didToggleFavorite(at index: Int) {
        guard displayedMovies.indices.contains(index) else { return }
        let movieID = displayedMovies[index].id
        if favoriteMovieIDs.contains(movieID) {
            favoriteMovieIDs.remove(movieID)
        } else {
            favoriteMovieIDs.insert(movieID)
        }
        rebuildItems()
    }

    func didToggleFavoritesFilter() {
        isFavoritesFilterActive.toggle()
        favoriteFilterActive.value = isFavoritesFilterActive
        rebuildItems()
    }
}

// MARK: - Private

private extension Array where Element == MoviesPage {
    var movies: [Movie] { flatMap { $0.movies } }
}
