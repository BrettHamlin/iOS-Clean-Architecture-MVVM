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

        typealias ExecuteBlock = (
            SearchMoviesUseCaseRequestValue,
            (MoviesPage) -> Void,
            (Result<MoviesPage, Error>) -> Void
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
            _execute(requestValue, cached, completion)
            return nil
        }
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
    
    //harness:criterion=c-existing-search-behavior-unaffected
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
        XCTAssertEqual(viewModel.items.value.count, moviesPages[0].movies.count)
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

    //harness:criterion=c-existing-search-behavior-unaffected
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

    //harness:criterion=c-input-protocol-did-toggle-favorite,c-input-protocol-did-toggle-favorites-filter
    func test_moviesListViewModelInputAcceptsFavoriteFilterInputs() {
        final class InputSpy: MoviesListViewModelInput {
            private(set) var toggledFavoriteIndex: Int?
            private(set) var didToggleFilter = false

            func viewDidLoad() { }
            func didLoadNextPage() { }
            func didSearch(query: String) { }
            func didCancelSearch() { }
            func showQueriesSuggestions() { }
            func closeQueriesSuggestions() { }
            func didSelectItem(at index: Int) { }
            func didToggleFavorite(at index: Int) {
                toggledFavoriteIndex = index
            }
            func didToggleFavoritesFilter() {
                didToggleFilter = true
            }
        }

        let spy = InputSpy()
        let input: MoviesListViewModelInput = spy

        input.didToggleFavorite(at: 4)
        input.didToggleFavoritesFilter()

        XCTAssertEqual(spy.toggledFavoriteIndex, 4)
        XCTAssertTrue(spy.didToggleFilter)
    }

    //harness:criterion=c-item-viewmodel-is-favorite-flag,c-item-viewmodel-init-accepts-is-favorite
    func test_moviesListItemViewModelStoresFavoriteFlagFromInitializer() {
        let movie = Movie.stub(id: "favorite-flag")

        let favoriteItem = MoviesListItemViewModel(movie: movie, isFavorite: true)
        let plainItem = MoviesListItemViewModel(movie: movie, isFavorite: false)

        XCTAssertTrue(favoriteItem.isFavorite)
        XCTAssertFalse(plainItem.isFavorite)
    }

    //harness:criterion=c-cell-favorite-button-outlet-exists
    func test_moviesListItemCellExposesFavoriteButtonCallbackSurface() {
        let cell = MoviesListItemCell(style: .default, reuseIdentifier: nil)
        let _: UIButton? = cell.favoriteButton
        var didTapFavorite = false

        cell.onFavoriteButtonTap = {
            didTapFavorite = true
        }
        cell.onFavoriteButtonTap?()

        XCTAssertTrue(didTapFavorite)
    }

    //harness:criterion=c-accessibility-id-favorite-button,c-accessibility-id-filter-control
    func test_accessibilityIdentifiersExposeFavoriteControls() {
        XCTAssertFalse(AccessibilityIdentifier.favoriteButton.isEmpty)
        XCTAssertFalse(AccessibilityIdentifier.favoritesFilterControl.isEmpty)
    }

    //harness:criterion=c-filter-control-exists-in-list-view
    func test_moviesListViewControllerExposesFavoritesFilterControlSurface() {
        let viewController = MoviesListViewController()
        let _: UISegmentedControl! = viewController.favoritesFilterControl
    }

    //harness:criterion=c-toggle-favorite-marks-item,c-recompute-items-called-on-favorite-toggle
    func test_whenTogglingFavorite_thenItemUpdatesSynchronously() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)

        XCTAssertTrue(viewModel.items.value[0].isFavorite)
    }

    //harness:criterion=c-toggle-favorite-twice-unmarks-item
    func test_whenTogglingFavoriteTwice_thenItemIsUnmarked() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavorite(at: 0)

        XCTAssertFalse(viewModel.items.value[0].isFavorite)
    }

    //harness:criterion=c-filter-mode-shows-only-favorites,c-recompute-items-called-on-filter-toggle
    func test_whenFavoritesFilterIsEnabled_thenOnlyFavoritedItemsAreVisibleSynchronously() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFavoritesFilter()

        XCTAssertEqual(viewModel.items.value.count, 1)
        XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })
        XCTAssertEqual(viewModel.items.value.first?.title, "title2")
    }

    //harness:criterion=c-filter-mode-toggle-back-shows-all
    func test_whenFavoritesFilterIsToggledBack_thenAllLoadedItemsAreVisible() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavoritesFilter()
        viewModel.didToggleFavoritesFilter()

        XCTAssertEqual(viewModel.items.value.count, moviesPages[0].movies.count)
    }

    //harness:criterion=c-filter-all-mode-items-count-equals-pages
    func test_whenAllFilterMode_thenItemsCountMatchesLoadedPages() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        viewModel.didSearch(query: "query")
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            completion(.success(self.moviesPages[1]))
        }
        viewModel.didLoadNextPage()

        XCTAssertEqual(viewModel.items.value.count, moviesPages.flatMap { $0.movies }.count)
    }

    //harness:criterion=c-did-select-item-resolves-under-filter
    func test_whenSelectingFavoriteFilteredItem_thenNavigatesToVisibleMovie() {
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "first", title: "first"),
            .stub(id: "second", title: "second"),
            .stub(id: "third", title: "third")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        var selectedMovie: Movie?
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: makeActions(showMovieDetails: { selectedMovie = $0 })
        )

        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 2)
        viewModel.didToggleFavoritesFilter()
        viewModel.didSelectItem(at: 0)

        XCTAssertEqual(viewModel.items.value.map { $0.title }, ["third"])
        XCTAssertEqual(selectedMovie?.id, "third")
    }

    //harness:criterion=c-did-select-item-resolves-in-all-mode
    func test_whenSelectingAllModeItem_thenNavigatesToUnfilteredMovie() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        var selectedMovie: Movie?
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: makeActions(showMovieDetails: { selectedMovie = $0 })
        )

        viewModel.didSearch(query: "query")
        viewModel.didSelectItem(at: 1)

        XCTAssertEqual(selectedMovie?.id, moviesPages[0].movies[1].id)
    }

    //harness:criterion=c-cached-page-callback-respects-filter
    func test_whenCachedPageArrivesInFavoritesMode_thenOnlyCachedFavoritesAreVisible() {
        let initialPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "favorite", title: "favorite original"),
            .stub(id: "plain", title: "plain original")
        ])
        let cachedPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "favorite", title: "favorite cached"),
            .stub(id: "plain", title: "plain cached")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(initialPage))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavoritesFilter()

        var didAssertCachedPage = false
        searchMoviesUseCaseMock._execute = { _, cached, completion in
            cached(cachedPage)
            didAssertCachedPage = true
            XCTAssertEqual(viewModel.items.value.count, 1)
            XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })
            XCTAssertEqual(viewModel.items.value.first?.title, "favorite cached")
            completion(.success(cachedPage))
        }

        viewModel.didSearch(query: "new query")

        XCTAssertTrue(didAssertCachedPage)
    }

    //harness:criterion=c-favorites-set-survives-new-search,c-items-is-favorite-reflects-persisted-id-set
    func test_whenNewSearchReturnsPreviouslyFavoritedMovie_thenItemRemainsFavorited() {
        let firstPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "kept-favorite", title: "first result"),
            .stub(id: "plain", title: "plain result")
        ])
        let secondPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "kept-favorite", title: "matching new result"),
            .stub(id: "another", title: "another result")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(firstPage))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)

        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(secondPage))
        }
        viewModel.didSearch(query: "new query")

        let matchingItem = viewModel.items.value.first { $0.title == "matching new result" }
        XCTAssertEqual(matchingItem?.isFavorite, true)
    }

    //harness:criterion=c-reset-pages-clears-visible-items
    func test_whenStartingNewSearch_thenVisibleItemsAreClearedInAllAndFavoritesModes() {
        assertStartingNewSearchClearsVisibleItems(activateFavoritesFilter: false)
        assertStartingNewSearchClearsVisibleItems(activateFavoritesFilter: true)
    }

    //harness:criterion=c-pagination-not-suppressed-by-short-favorites-list
    func test_whenFavoritesFilterShowsShortList_thenLoadNextPageStillFetches() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavoritesFilter()

        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            completion(.success(self.moviesPages[1]))
        }
        viewModel.didLoadNextPage()

        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 2)
    }

    //harness:criterion=c-toggle-favorite-out-of-bounds-no-crash
    func test_whenTogglingFavoriteOutOfBounds_thenItemsAreUnchanged() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        let originalItems = viewModel.items.value

        viewModel.didToggleFavorite(at: originalItems.count)

        XCTAssertEqual(viewModel.items.value, originalItems)
        XCTAssertFalse(viewModel.items.value.contains { $0.isFavorite })
    }

    //harness:criterion=c-toggle-favorite-out-of-bounds-no-crash
    func test_whenTogglingFavoriteWithNegativeIndex_thenItemsAreUnchanged() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        let originalItems = viewModel.items.value

        viewModel.didToggleFavorite(at: -1)

        XCTAssertEqual(viewModel.items.value, originalItems)
        XCTAssertFalse(viewModel.items.value.contains { $0.isFavorite })
    }

    //harness:criterion=c-toggle-favorite-out-of-bounds-no-crash
    func test_whenTogglingFavoriteOutsideFilteredVisibleItems_thenHiddenLoadedItemIsNotMutated() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavoritesFilter()
        XCTAssertEqual(viewModel.items.value.count, 1)

        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFavoritesFilter()

        XCTAssertEqual(viewModel.items.value.count, moviesPages[0].movies.count)
        XCTAssertTrue(viewModel.items.value[0].isFavorite)
        XCTAssertFalse(viewModel.items.value[1].isFavorite)
    }

    //harness:criterion=c-items-is-favorite-reflects-persisted-id-set
    func test_whenLaterPageContainsAlreadyFavoritedMovie_thenAppendedItemIsFavoriteImmediately() {
        let firstPage = MoviesPage(page: 1, totalPages: 2, movies: [
            .stub(id: "persisted-favorite", title: "original favorite"),
            .stub(id: "plain", title: "plain")
        ])
        let secondPage = MoviesPage(page: 2, totalPages: 2, movies: [
            .stub(id: "persisted-favorite", title: "returned favorite"),
            .stub(id: "new-plain", title: "new plain")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(firstPage))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)

        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            completion(.success(secondPage))
        }
        viewModel.didLoadNextPage()

        let appendedFavorite = viewModel.items.value.first { $0.title == "returned favorite" }
        XCTAssertEqual(appendedFavorite?.isFavorite, true)
    }

    //harness:criterion=c-recompute-items-called-on-filter-toggle
    func test_whenFavoritesFilterToggles_thenFilterStateAndItemsUpdateSynchronously() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavoritesFilter()

        XCTAssertTrue(viewModel.isFavoritesFilterEnabled.value)
        XCTAssertEqual(viewModel.items.value.count, 1)

        viewModel.didToggleFavoritesFilter()

        XCTAssertFalse(viewModel.isFavoritesFilterEnabled.value)
        XCTAssertEqual(viewModel.items.value.count, moviesPages[0].movies.count)
    }

    private func assertStartingNewSearchClearsVisibleItems(
        activateFavoritesFilter: Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        if activateFavoritesFilter {
            viewModel.didToggleFavorite(at: 0)
            viewModel.didToggleFavoritesFilter()
        }
        XCTAssertFalse(viewModel.items.value.isEmpty, file: file, line: line)

        var didAssertResetState = false
        searchMoviesUseCaseMock._execute = { _, _, _ in
            didAssertResetState = true
            XCTAssertTrue(viewModel.items.value.isEmpty, file: file, line: line)
        }

        viewModel.didSearch(query: activateFavoritesFilter ? "favorites query" : "all query")

        XCTAssertTrue(didAssertResetState, file: file, line: line)
    }

    private func makeActions(
        showMovieDetails: @escaping (Movie) -> Void
    ) -> MoviesListViewModelActions {
        MoviesListViewModelActions(
            showMovieDetails: showMovieDetails,
            showMovieQueriesSuggestions: { _ in },
            closeMovieQueriesSuggestions: { }
        )
    }

}

extension DefaultMoviesListViewModel {
    static func make(
        searchMoviesUseCase: SearchMoviesUseCase,
        actions: MoviesListViewModelActions? = nil
    ) -> DefaultMoviesListViewModel {
        DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCase,
            actions: actions,
            mainQueue: DispatchQueueTypeMock()
        )
    }
}
