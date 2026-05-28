import XCTest
import UIKit

class MoviesListViewModelTests: XCTestCase {
    
    private enum SearchMoviesUseCaseError: Error {
        case someError
    }
    
    let moviesPages: [MoviesPage] = {
        let page1 = MoviesPage(page: 1, totalPages: 2, movies: [
            Movie.stub(id: "1", title: "title1", posterPath: "/1", overview: "overview1"),
            Movie.stub(id: "2", title: "title2", posterPath: "/2", overview: "overview2")])
        let page2 = MoviesPage(page: 2, totalPages: 2, movies: [
            Movie.stub(id: "3", title: "title3", posterPath: "/3", overview: "overview3")])
        return [page1, page2]
    }()
    
    class SearchMoviesUseCaseMock: SearchMoviesUseCase {
        var executeCallCount: Int = 0
        var latestRequestValue: SearchMoviesUseCaseRequestValue?

        typealias ExecuteBlock = (
            SearchMoviesUseCaseRequestValue,
            @escaping (MoviesPage) -> Void,
            @escaping (Result<MoviesPage, Error>) -> Void
        ) -> Void

        lazy var _execute: ExecuteBlock = { _, _, _ in
            XCTFail("not implemented")
        }
        
        func execute(
            requestValue: SearchMoviesUseCaseRequestValue,
            cached: @escaping (MoviesPage) -> Void,
            completion: @escaping (Result<MoviesPage, Error>) -> Void
        ) -> Cancellable? {
            executeCallCount += 1
            latestRequestValue = requestValue
            _execute(requestValue, cached, completion)
            return nil
        }
    }

    private final class MoviesListViewModelMock: MoviesListViewModel {
        let items: Observable<[MoviesListItemViewModel]> = Observable([])
        let loading: Observable<MoviesListViewModelLoading?> = Observable(.none)
        let query: Observable<String> = Observable("")
        let error: Observable<String> = Observable("")
        let favoriteFilterActive: Observable<Bool> = Observable(false)
        var isEmpty: Bool { items.value.isEmpty }
        let screenTitle = "Movies"
        let emptyDataTitle = "Search results"
        let errorTitle = "Error"
        let searchBarPlaceholder = "Search Movies"
        var didToggleFavoritesFilterCallCount = 0

        func viewDidLoad() {}
        func didLoadNextPage() {}
        func didSearch(query: String) {}
        func didCancelSearch() {}
        func showQueriesSuggestions() {}
        func closeQueriesSuggestions() {}
        func didSelectItem(at index: Int) {}
        func didToggleFavorite(at index: Int) {}
        func didToggleFavoritesFilter() {
            didToggleFavoritesFilterCallCount += 1
        }
    }

    private func makeViewModel(
        returning page: MoviesPage,
        actions: MoviesListViewModelActions? = nil
    ) -> (DefaultMoviesListViewModel, SearchMoviesUseCaseMock) {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(page))
        }
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: actions,
            mainQueue: DispatchQueueTypeMock()
        )
        viewModel.didSearch(query: "query")
        return (viewModel, searchMoviesUseCaseMock)
    }

    private func localizedString(
        key: String,
        localization: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        for bundle in bundles {
            guard let path = bundle.path(forResource: localization, ofType: "lproj"),
                  let localizedBundle = Bundle(path: path) else { continue }
            let missingValue = "__missing_\(key)__"
            let value = localizedBundle.localizedString(forKey: key, value: missingValue, table: nil)
            if value != missingValue {
                return value
            }
        }
        XCTFail("Missing localized value for \(key) in \(localization)", file: file, line: line)
        return ""
    }

    func test_itemViewModelFavoriteFlagAndEquatableIncludeFavoriteState() {
        //harness:criterion=c-item-viewmodel-is-favorite-property,c-item-viewmodel-init-favorite-flag,c-item-viewmodel-equatable-includes-favorite,c-movie-stub-id-param
        let movie = Movie.stub(id: "favorite-id", title: "Same movie")

        let favoriteItem = MoviesListItemViewModel(movie: movie, isFavorite: true)
        let nonFavoriteItem = MoviesListItemViewModel(movie: movie, isFavorite: false)

        XCTAssertTrue(favoriteItem.isFavorite)
        XCTAssertFalse(nonFavoriteItem.isFavorite)
        XCTAssertNotEqual(favoriteItem, nonFavoriteItem)
    }

    func test_viewModelFavoriteAPISurfacesAreUsableThroughProtocols() {
        //harness:criterion=c-viewmodel-input-toggle-favorite,c-viewmodel-input-toggle-filter,c-viewmodel-output-filter-active
        let (viewModel, _) = makeViewModel(returning: moviesPages[0])
        let input: MoviesListViewModelInput = viewModel
        let output: MoviesListViewModelOutput = viewModel

        input.didToggleFavorite(at: 0)
        input.didToggleFavoritesFilter()

        XCTAssertTrue(output.items.value[0].isFavorite)
        XCTAssertTrue(output.favoriteFilterActive.value)
    }

    func test_whenToggleFavoriteOnceAndTwice_thenMarksAndUnmarksWithoutSearch() {
        //harness:criterion=c-toggle-favorite-marks-item,c-toggle-favorite-unmarks-item,c-toggle-favorite-no-extra-search-calls
        let (viewModel, searchMoviesUseCaseMock) = makeViewModel(returning: moviesPages[0])
        let executeCallCount = searchMoviesUseCaseMock.executeCallCount

        viewModel.didToggleFavorite(at: 0)

        XCTAssertTrue(viewModel.items.value[0].isFavorite)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, executeCallCount)

        viewModel.didToggleFavorite(at: 0)

        XCTAssertFalse(viewModel.items.value[0].isFavorite)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, executeCallCount)
    }

    func test_whenFavoritesFilterToggles_thenFiltersItemsAndPublishesStateWithoutSearch() {
        //harness:criterion=c-favorites-filter-shows-only-favorited,c-favorites-filter-all-shows-all,c-favorites-filter-active-observable-true,c-favorites-filter-active-observable-false,c-toggle-filter-no-extra-search-calls,c-favorite-state-persists-across-filter-toggle
        let (viewModel, searchMoviesUseCaseMock) = makeViewModel(returning: moviesPages[0])
        viewModel.didToggleFavorite(at: 1)
        let executeCallCount = searchMoviesUseCaseMock.executeCallCount

        viewModel.didToggleFavoritesFilter()

        XCTAssertTrue(viewModel.favoriteFilterActive.value)
        XCTAssertEqual(viewModel.items.value.count, 1)
        XCTAssertEqual(viewModel.items.value[0].title, "title2")
        XCTAssertTrue(viewModel.items.value.allSatisfy(\.isFavorite))
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, executeCallCount)

        viewModel.didToggleFavoritesFilter()

        XCTAssertFalse(viewModel.favoriteFilterActive.value)
        XCTAssertEqual(viewModel.items.value.count, moviesPages[0].movies.count)
        XCTAssertTrue(viewModel.items.value[1].isFavorite)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, executeCallCount)
    }

    func test_whenFavoritesFilterActivatedWithNoFavorites_thenItemsAreEmpty() {
        //harness:criterion=c-favorites-empty-filter-shows-empty-list
        let (viewModel, _) = makeViewModel(returning: moviesPages[0])

        viewModel.didToggleFavoritesFilter()

        XCTAssertTrue(viewModel.items.value.isEmpty)
    }

    func test_whenFavoritesFilterActive_thenToggleFavoriteUsesDisplayedIndex() {
        //harness:criterion=c-toggle-favorite-unmarks-item,c-favorites-filter-shows-only-favorited
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "unfavorited", title: "unfavorited"),
            Movie.stub(id: "favorite-1", title: "favorite 1"),
            Movie.stub(id: "favorite-2", title: "favorite 2")
        ])
        let (viewModel, _) = makeViewModel(returning: page)
        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFavorite(at: 2)
        viewModel.didToggleFavoritesFilter()

        viewModel.didToggleFavorite(at: 0)

        XCTAssertEqual(viewModel.items.value.map(\.title), ["favorite 2"])
        XCTAssertTrue(viewModel.items.value.allSatisfy(\.isFavorite))

        viewModel.didToggleFavoritesFilter()

        XCTAssertFalse(viewModel.items.value[0].isFavorite)
        XCTAssertFalse(viewModel.items.value[1].isFavorite)
        XCTAssertTrue(viewModel.items.value[2].isFavorite)
    }

    func test_whenFavoriteStateIsInMemoryOnly_thenNewViewModelStartsWithoutFavorites() {
        //harness:criterion=c-favorite-state-in-memory-only
        let (firstViewModel, _) = makeViewModel(returning: moviesPages[0])
        firstViewModel.didToggleFavorite(at: 0)
        XCTAssertTrue(firstViewModel.items.value[0].isFavorite)

        let (secondViewModel, _) = makeViewModel(returning: moviesPages[0])

        XCTAssertFalse(secondViewModel.items.value[0].isFavorite)
    }

    func test_whenFavoritesFilterActive_thenDidSelectUsesDisplayedIndex() {
        //harness:criterion=c-select-item-correct-movie-filter-active
        var selectedMovie: Movie?
        let actions = MoviesListViewModelActions(
            showMovieDetails: { selectedMovie = $0 },
            showMovieQueriesSuggestions: { _ in },
            closeMovieQueriesSuggestions: {}
        )
        let (viewModel, _) = makeViewModel(returning: moviesPages[0], actions: actions)
        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFavoritesFilter()

        viewModel.didSelectItem(at: 0)

        XCTAssertEqual(selectedMovie?.id, "2")
    }

    func test_whenFavoritesFilterActive_thenDidSelectUsesNonZeroDisplayedIndex() {
        //harness:criterion=c-select-item-correct-movie-filter-active
        var selectedMovie: Movie?
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "first-favorite", title: "first favorite"),
            Movie.stub(id: "hidden", title: "hidden"),
            Movie.stub(id: "second-favorite", title: "second favorite")
        ])
        let actions = MoviesListViewModelActions(
            showMovieDetails: { selectedMovie = $0 },
            showMovieQueriesSuggestions: { _ in },
            closeMovieQueriesSuggestions: {}
        )
        let (viewModel, _) = makeViewModel(returning: page, actions: actions)
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavorite(at: 2)
        viewModel.didToggleFavoritesFilter()

        viewModel.didSelectItem(at: 1)

        XCTAssertEqual(viewModel.items.value.map(\.title), ["first favorite", "second favorite"])
        XCTAssertEqual(selectedMovie?.id, "second-favorite")
    }

    func test_whenFavoritesFilterActive_thenPaginationRequestsAreBlocked() {
        //harness:criterion=c-load-next-page-blocked-while-filter-active,c-last-row-pagination-guard-filter-active
        let (viewModel, searchMoviesUseCaseMock) = makeViewModel(returning: moviesPages[0])
        viewModel.didToggleFavoritesFilter()
        let executeCallCount = searchMoviesUseCaseMock.executeCallCount

        viewModel.didLoadNextPage()

        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, executeCallCount)
    }

    func test_whenSecondPageCompletesWhileFilterActive_thenOnlyFavoritesRemainVisible() {
        //harness:criterion=c-append-page-applies-filter
        let (viewModel, searchMoviesUseCaseMock) = makeViewModel(returning: moviesPages[0])
        viewModel.didToggleFavorite(at: 0)
        var pendingCompletion: ((Result<MoviesPage, Error>) -> Void)?
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            pendingCompletion = completion
        }
        viewModel.didLoadNextPage()
        viewModel.didToggleFavoritesFilter()

        pendingCompletion?(.success(moviesPages[1]))

        XCTAssertEqual(viewModel.items.value.count, 1)
        XCTAssertEqual(viewModel.items.value[0].title, "title1")
        XCTAssertTrue(viewModel.items.value[0].isFavorite)
    }

    func test_whenSearchSubmittedWithFilterInactive_thenUsesQueryAndLoadsResults() {
        //harness:criterion=c-search-preserved-with-filter-inactive
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        viewModel.didSearch(query: "contract-query")

        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 1)
        XCTAssertEqual(searchMoviesUseCaseMock.latestRequestValue?.query.query, "contract-query")
        XCTAssertEqual(viewModel.items.value.count, moviesPages[0].movies.count)
    }

    func test_whenSearchSubmittedWhileFilterActive_thenFilterResetsAndAllNewResultsAreShown() {
        //harness:criterion=c-search-resets-filter
        let (viewModel, searchMoviesUseCaseMock) = makeViewModel(returning: moviesPages[0])
        viewModel.didToggleFavoritesFilter()
        XCTAssertTrue(viewModel.items.value.isEmpty)

        let newResults = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "new-1", title: "new title 1"),
            Movie.stub(id: "new-2", title: "new title 2")
        ])
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.query.query, "new-query")
            completion(.success(newResults))
        }

        viewModel.didSearch(query: "new-query")

        XCTAssertFalse(viewModel.favoriteFilterActive.value)
        XCTAssertEqual(viewModel.items.value.count, newResults.movies.count)
        XCTAssertTrue(viewModel.items.value.allSatisfy { !$0.isFavorite })
    }

    func test_whenFilterInactive_thenLoadNextPageStillRequestsNextPage() {
        //harness:criterion=c-pagination-preserved-filter-inactive
        let (viewModel, searchMoviesUseCaseMock) = makeViewModel(returning: moviesPages[0])
        let executeCallCount = searchMoviesUseCaseMock.executeCallCount
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            completion(.success(self.moviesPages[1]))
        }

        viewModel.didLoadNextPage()

        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, executeCallCount + 1)
        XCTAssertEqual(searchMoviesUseCaseMock.latestRequestValue?.page, 2)
    }

    func test_whenFilterInactive_thenSelectionUsesUnfilteredIndex() {
        //harness:criterion=c-movie-details-navigation-preserved
        var selectedMovie: Movie?
        let actions = MoviesListViewModelActions(
            showMovieDetails: { selectedMovie = $0 },
            showMovieQueriesSuggestions: { _ in },
            closeMovieQueriesSuggestions: {}
        )
        let (viewModel, _) = makeViewModel(returning: moviesPages[0], actions: actions)

        viewModel.didSelectItem(at: 1)

        XCTAssertEqual(selectedMovie?.id, moviesPages[0].movies[1].id)
    }

    func test_favoriteCellAndFilterControlExposeUsableUIBindings() {
        //harness:criterion=c-cell-favorite-star-button-present,c-cell-star-tap-calls-toggle-favorite,c-view-controller-filter-toggle-control-present,c-view-controller-toggle-wired-to-viewmodel,c-localizable-all-key-en,c-localizable-favorites-key-en,c-localizable-all-key-es,c-localizable-favorites-key-es
        let cell = MoviesListItemCell(style: .default, reuseIdentifier: nil)
        cell.awakeFromNib()

        XCTAssertNotNil(cell.favoriteButton)
        let cellActions = cell.favoriteButton.actions(forTarget: cell, forControlEvent: .touchUpInside) ?? []
        XCTAssertTrue(cellActions.contains("didTapFavoriteButton"))
        var favoriteTapCallCount = 0
        cell.onFavoriteButtonTapped = { favoriteTapCallCount += 1 }
        cell.onFavoriteButtonTapped?()
        XCTAssertEqual(favoriteTapCallCount, 1)

        let viewController = MoviesListViewController()
        let control = viewController.favoritesFilterControl
        XCTAssertEqual(control.numberOfSegments, 2)
        XCTAssertEqual(control.titleForSegment(at: 0), localizedString(key: "All", localization: "en"))
        XCTAssertEqual(control.titleForSegment(at: 1), localizedString(key: "Favorites", localization: "en"))
        XCTAssertFalse(localizedString(key: "All", localization: "es").isEmpty)
        XCTAssertFalse(localizedString(key: "Favorites", localization: "es").isEmpty)

        let controlActions = control.actions(forTarget: viewController, forControlEvent: .valueChanged) ?? []
        XCTAssertTrue(controlActions.contains("didChangeFavoritesFilter"))
    }

    func test_viewControllerObservesFavoriteFilterActiveAndUpdatesControlState() {
        //harness:criterion=c-view-controller-observes-filter-active
        let viewModel = MoviesListViewModelMock()
        let viewController = MoviesListViewController.create(
            with: viewModel,
            posterImagesRepository: nil
        )
        viewController.loadViewIfNeeded()

        viewModel.favoriteFilterActive.value = true

        XCTAssertEqual(viewController.favoritesFilterControl.selectedSegmentIndex, 1)
    }
    
    func test_whenSearchMoviesUseCaseRetrievesEmptyPage_thenViewModelIsEmpty() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()

        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(MoviesPage(page: 1, totalPages: 0, movies: [])))
        }
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: DispatchQueueTypeMock()
        )
        // when
        viewModel.didSearch(query: "query")
        
        // then
        XCTAssertEqual(viewModel.currentPage, 1)
        XCTAssertFalse(viewModel.hasMorePages)
        XCTAssertTrue(viewModel.items.value.isEmpty)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 1)
    }
    
    func test_whenSearchMoviesUseCaseRetrievesFirstPage_thenViewModelContainsOnlyFirstPage() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()

        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: DispatchQueueTypeMock()
        )
        // when
        viewModel.didSearch(query: "query")
        
        // then
        let expectedItems = moviesPages[0]
            .movies
            .map { MoviesListItemViewModel(movie: $0) }
        XCTAssertEqual(viewModel.items.value, expectedItems)
        XCTAssertEqual(viewModel.currentPage, 1)
        XCTAssertTrue(viewModel.hasMorePages)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 1)
    }
    
    func test_whenSearchMoviesUseCaseRetrievesFirstAndSecondPage_thenViewModelContainsTwoPages() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()

        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        // when
        viewModel.didSearch(query: "query")
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 1)
        
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            completion(.success(self.moviesPages[1]))
        }

        viewModel.didLoadNextPage()

        // then
        let expectedItems = moviesPages
            .flatMap { $0.movies }
            .map { MoviesListItemViewModel(movie: $0) }
        XCTAssertEqual(viewModel.items.value, expectedItems)
        XCTAssertEqual(viewModel.currentPage, 2)
        XCTAssertFalse(viewModel.hasMorePages)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 2)
    }

    func test_whenSearchMoviesUseCaseReturnsError_thenViewModelContainsError() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.failure(SearchMoviesUseCaseError.someError))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        // when
        viewModel.didSearch(query: "query")

        // then
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.items.value.isEmpty)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 1)
    }

    func test_whenLastPage_thenHasNoPageIsTrue() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        // when
        viewModel.didSearch(query: "query")
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 1)

        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            completion(.success(self.moviesPages[1]))
        }

        viewModel.didLoadNextPage()

        // then
        XCTAssertEqual(viewModel.currentPage, 2)
        XCTAssertFalse(viewModel.hasMorePages)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 2)
    }
    
    func test_whenSearchMoviesUseCaseReturnsCachedData_thenViewModelShowsFirstCachedDataAndAfterFreshData() {
        // given
        let cachedPage: MoviesPage = .init(
            page: 1,
            totalPages: 2,
            movies: [.stub(id: "cachedMovieId1")]
        )
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: DispatchQueueTypeMock()
        )
        
        let testItemsBeforeFreshData = { [weak viewModel] in
            guard let viewModel else { return }
            let expectedItems = cachedPage
                .movies
                .map { MoviesListItemViewModel(movie: $0) }
        
            XCTAssertEqual(viewModel.items.value, expectedItems)
        }

        searchMoviesUseCaseMock._execute = { requestValue, cached, completion in
            XCTAssertEqual(requestValue.page, 1)
            cached(cachedPage)
            testItemsBeforeFreshData()
            completion(.success(self.moviesPages[0]))
        }
        
        // when
        viewModel.didSearch(query: "query")

        // then
        let expectedItems = moviesPages[0]
            .movies
            .map { MoviesListItemViewModel(movie: $0) }
        XCTAssertEqual(viewModel.items.value, expectedItems)
        XCTAssertEqual(viewModel.currentPage, 1)
        XCTAssertTrue(viewModel.hasMorePages)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 1)
    }
    
    func test_whenSearchMoviesUseCaseReturnsError_thenViewModelShowsCachedData() {
        // given
        let cachedPage: MoviesPage = .init(
            page: 1,
            totalPages: 2,
            movies: [.stub(id: "cachedMovieId1")]
        )
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: DispatchQueueTypeMock()
        )

        searchMoviesUseCaseMock._execute = { requestValue, cached, completion in
            XCTAssertEqual(requestValue.page, 1)
            cached(cachedPage)
            completion(.failure(SearchMoviesUseCaseError.someError))
        }
        
        // when
        viewModel.didSearch(query: "query")

        // then
        let expectedItems = cachedPage
            .movies
            .map { MoviesListItemViewModel(movie: $0) }
        XCTAssertEqual(viewModel.items.value, expectedItems)
        XCTAssertEqual(viewModel.currentPage, 1)
        XCTAssertTrue(viewModel.hasMorePages)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 1)
    }

}

extension DefaultMoviesListViewModel {
    static func make(
        searchMoviesUseCase: SearchMoviesUseCase
    ) -> DefaultMoviesListViewModel {
        DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCase,
            mainQueue: DispatchQueueTypeMock()
        )
    }
}
