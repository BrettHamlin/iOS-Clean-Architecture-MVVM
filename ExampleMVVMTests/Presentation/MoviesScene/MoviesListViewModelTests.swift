import XCTest

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
        var requestValues: [SearchMoviesUseCaseRequestValue] = []

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
            requestValues.append(requestValue)
            _execute(requestValue, cached, completion)
            return nil
        }
    }
    
    // harness:criterion=c-existing-search-behavior-preserved,c-existing-vm-tests-remain-green
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
    
    // harness:criterion=c-existing-search-behavior-preserved,c-existing-vm-tests-remain-green
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
    
    // harness:criterion=c-existing-search-behavior-preserved,c-pagination-trigger-preserved,c-existing-vm-tests-remain-green
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

    // harness:criterion=c-existing-error-behavior-preserved,c-existing-vm-tests-remain-green
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

    // harness:criterion=c-pagination-trigger-preserved,c-existing-vm-tests-remain-green
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
    
    // harness:criterion=c-existing-cached-result-display-preserved,c-existing-vm-tests-remain-green
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
    
    // harness:criterion=c-existing-error-behavior-preserved,c-existing-cached-result-display-preserved,c-existing-vm-tests-remain-green
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

    // harness:criterion=c-input-has-did-toggle-favorite,c-toggle-favorite-marks-item,c-toggle-favorite-unmarks-item,c-item-viewmodel-has-is-favorite
    func test_whenFavoriteIsToggled_thenItemFavoriteStateIsUpdated() {
        // given
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorite-id", title: "Favorite"),
            Movie.stub(id: "plain-id", title: "Plain")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        let viewModel: MoviesListViewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")

        // when
        viewModel.didToggleFavorite(at: 0)

        // then
        XCTAssertTrue(viewModel.items.value[0].isFavorite)
        XCTAssertFalse(viewModel.items.value[1].isFavorite)

        // when
        viewModel.didToggleFavorite(at: 0)

        // then
        XCTAssertFalse(viewModel.items.value[0].isFavorite)
    }

    // harness:criterion=c-input-has-did-toggle-favorites-filter,c-filter-shows-only-favorites,c-filter-toggle-back-shows-all
    func test_whenFavoritesFilterIsToggled_thenVisibleItemsSwitchBetweenFavoritesAndAllMovies() {
        // given
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorite-id", title: "Favorite"),
            Movie.stub(id: "plain-id", title: "Plain")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)

        // when
        viewModel.didToggleFavoritesFilter()

        // then
        XCTAssertEqual(viewModel.items.value.count, 1)
        XCTAssertEqual(viewModel.items.value[0].title, "Favorite")
        XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })

        // when
        viewModel.didToggleFavoritesFilter()

        // then
        XCTAssertEqual(viewModel.items.value.count, 2)
    }

    // harness:criterion=c-toggle-favorite-unmarks-item,c-filter-shows-only-favorites
    func test_whenFavoriteIsUntoggledWhileFavoritesFilterIsActive_thenItIsRemovedFromVisibleItems() {
        // given
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "plain-id", title: "Plain"),
            Movie.stub(id: "favorite-id", title: "Favorite")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFavoritesFilter()
        XCTAssertEqual(viewModel.items.value.map { $0.title }, ["Favorite"])

        // when
        viewModel.didToggleFavorite(at: 0)

        // then
        XCTAssertTrue(viewModel.items.value.isEmpty)
    }

    // harness:criterion=c-output-has-filter-mode-observable,c-filter-mode-output-reflects-state
    func test_whenFavoritesFilterIsToggled_thenFilterModeObservableReflectsState() {
        // given
        let viewModel: MoviesListViewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        var observedModes: [MoviesListViewModelFilterMode] = []

        // when
        viewModel.filterMode.observe(on: self) { observedModes.append($0) }
        viewModel.didToggleFavoritesFilter()
        viewModel.didToggleFavoritesFilter()

        // then
        XCTAssertEqual(observedModes.count, 3)
        XCTAssertTrue(observedModes[0].isAllMovies)
        XCTAssertTrue(observedModes[1].isFavoritesOnly)
        XCTAssertTrue(observedModes[2].isAllMovies)
    }

    // harness:criterion=c-select-item-resolves-against-filtered-list
    func test_whenSelectingItemWithFavoritesFilterActive_thenSelectedMovieComesFromFilteredList() {
        // given
        let rawFirstMovie = Movie.stub(id: "raw-first-id", title: "Raw First")
        let filteredMovie = Movie.stub(id: "filtered-id", title: "Filtered")
        let page = MoviesPage(page: 1, totalPages: 1, movies: [rawFirstMovie, filteredMovie])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        var selectedMovie: Movie?
        let actions = MoviesListViewModelActions(
            showMovieDetails: { selectedMovie = $0 },
            showMovieQueriesSuggestions: { _ in },
            closeMovieQueriesSuggestions: {}
        )
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: actions,
            mainQueue: DispatchQueueTypeMock()
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFavoritesFilter()

        // when
        viewModel.didSelectItem(at: 0)

        // then
        XCTAssertEqual(selectedMovie, filteredMovie)
    }

    // harness:criterion=c-existing-details-navigation-preserved
    func test_whenSelectingItemWithDefaultFilter_thenSelectedMovieComesFromFullList() {
        // given
        let firstMovie = Movie.stub(id: "first-id", title: "First")
        let secondMovie = Movie.stub(id: "second-id", title: "Second")
        let page = MoviesPage(page: 1, totalPages: 1, movies: [firstMovie, secondMovie])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        var selectedMovie: Movie?
        let actions = MoviesListViewModelActions(
            showMovieDetails: { selectedMovie = $0 },
            showMovieQueriesSuggestions: { _ in },
            closeMovieQueriesSuggestions: {}
        )
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: actions,
            mainQueue: DispatchQueueTypeMock()
        )
        viewModel.didSearch(query: "query")

        // when
        viewModel.didSelectItem(at: 1)

        // then
        XCTAssertEqual(selectedMovie, secondMovie)
    }

    // harness:criterion=c-load-next-page-resolves-against-filtered-list
    func test_whenLoadingNextPageWithFavoritesFilterActive_thenNextRequestUsesRawLoadedPageProgress() {
        // given
        let page = MoviesPage(page: 1, totalPages: 2, movies: [
            Movie.stub(id: "1", title: "Movie 1"),
            Movie.stub(id: "2", title: "Movie 2"),
            Movie.stub(id: "3", title: "Movie 3"),
            Movie.stub(id: "4", title: "Movie 4"),
            Movie.stub(id: "5", title: "Movie 5")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            if requestValue.page == 1 {
                completion(.success(page))
            } else {
                completion(.success(MoviesPage(page: 2, totalPages: 2, movies: [])))
            }
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFavoritesFilter()

        // when
        viewModel.didLoadNextPage()

        // then
        XCTAssertEqual(viewModel.items.value.count, 2)
        XCTAssertEqual(searchMoviesUseCaseMock.requestValues.map { $0.page }, [1, 2])
    }

    // harness:criterion=c-favorites-survive-new-search
    func test_whenNewSearchReturnsPreviouslyFavoritedMovie_thenFavoriteStateSurvivesReset() {
        // given
        let favoritedMovie = Movie.stub(id: "survives-id", title: "Survives")
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(MoviesPage(page: 1, totalPages: 1, movies: [favoritedMovie])))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "first")
        viewModel.didToggleFavorite(at: 0)

        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(MoviesPage(page: 1, totalPages: 1, movies: [
                Movie.stub(id: "survives-id", title: "Survives Again")
            ])))
        }

        // when
        viewModel.didSearch(query: "second")

        // then
        XCTAssertEqual(viewModel.items.value.count, 1)
        XCTAssertEqual(viewModel.items.value[0].title, "Survives Again")
        XCTAssertTrue(viewModel.items.value[0].isFavorite)
    }

    // harness:criterion=c-favorites-filter-applied-on-cached-results
    func test_whenCachedResultsArriveWithFavoritesFilterActive_thenOnlyFavoritedCachedMoviesAreVisible() {
        // given
        let favoritedMovie = Movie.stub(id: "cached-favorite-id", title: "Cached Favorite")
        let cachedPage = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "cached-favorite-id", title: "Cached Favorite Again"),
            Movie.stub(id: "cached-plain-id", title: "Cached Plain")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(MoviesPage(page: 1, totalPages: 1, movies: [favoritedMovie])))
        }
        viewModel.didSearch(query: "seed")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavoritesFilter()

        searchMoviesUseCaseMock._execute = { _, cached, completion in
            cached(cachedPage)
            XCTAssertEqual(viewModel.items.value.count, 1)
            XCTAssertEqual(viewModel.items.value[0].title, "Cached Favorite Again")
            XCTAssertTrue(viewModel.items.value[0].isFavorite)
            completion(.success(cachedPage))
        }

        // when
        viewModel.didSearch(query: "cached")

        // then
        XCTAssertEqual(viewModel.items.value.count, 1)
        XCTAssertEqual(viewModel.items.value[0].title, "Cached Favorite Again")
        XCTAssertTrue(viewModel.items.value[0].isFavorite)
    }

    // harness:criterion=c-favorites-filter-applied-on-pagination
    func test_whenPageIsAppendedWithFavoritesFilterActive_thenOnlyFavoritedMoviesAcrossPagesAreVisible() {
        // given
        let pageOneFavorite = Movie.stub(id: "page-one-favorite-id", title: "Page One Favorite")
        let pageTwoFavorite = Movie.stub(id: "page-two-favorite-id", title: "Page Two Favorite")
        let pageOne = MoviesPage(page: 1, totalPages: 2, movies: [
            pageOneFavorite,
            Movie.stub(id: "page-one-plain-id", title: "Page One Plain")
        ])
        let pageTwo = MoviesPage(page: 2, totalPages: 2, movies: [
            pageTwoFavorite,
            Movie.stub(id: "page-two-plain-id", title: "Page Two Plain")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )

        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(MoviesPage(page: 1, totalPages: 1, movies: [pageTwoFavorite])))
        }
        viewModel.didSearch(query: "seed-page-two-favorite")
        viewModel.didToggleFavorite(at: 0)

        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            switch requestValue.page {
            case 1:
                completion(.success(pageOne))
            case 2:
                completion(.success(pageTwo))
            default:
                XCTFail("Unexpected page \(requestValue.page)")
            }
        }
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavoritesFilter()

        // when
        viewModel.didLoadNextPage()

        // then
        XCTAssertEqual(viewModel.items.value.map { $0.title }, ["Page One Favorite", "Page Two Favorite"])
        XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })
    }

    // harness:criterion=c-item-viewmodel-equatable-includes-is-favorite
    func test_whenItemViewModelsDifferOnlyByFavoriteState_thenTheyAreNotEqual() {
        // given
        let movie = Movie.stub(id: "same-id", title: "Same")

        // when
        let favoriteItem = MoviesListItemViewModel(movie: movie, isFavorite: true)
        let nonFavoriteItem = MoviesListItemViewModel(movie: movie, isFavorite: false)

        // then
        XCTAssertNotEqual(favoriteItem, nonFavoriteItem)
    }

    // harness:criterion=c-no-persistence-no-new-dependencies
    func test_whenNewViewModelLoadsPreviouslyFavoritedMovie_thenFavoriteStateIsNotSharedAcrossInstances() {
        // given
        let movie = Movie.stub(id: "local-only-id", title: "Local Only")
        let firstSearchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        firstSearchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(MoviesPage(page: 1, totalPages: 1, movies: [movie])))
        }
        let firstViewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: firstSearchMoviesUseCaseMock
        )
        firstViewModel.didSearch(query: "query")
        firstViewModel.didToggleFavorite(at: 0)
        XCTAssertTrue(firstViewModel.items.value[0].isFavorite)

        let secondSearchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        secondSearchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(MoviesPage(page: 1, totalPages: 1, movies: [movie])))
        }
        let secondViewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: secondSearchMoviesUseCaseMock
        )

        // when
        secondViewModel.didSearch(query: "query")

        // then
        XCTAssertFalse(secondViewModel.items.value[0].isFavorite)
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

private extension MoviesListViewModelFilterMode {
    var isAllMovies: Bool {
        if case .all = self { return true }
        return false
    }

    var isFavoritesOnly: Bool {
        if case .favorites = self { return true }
        return false
    }
}
