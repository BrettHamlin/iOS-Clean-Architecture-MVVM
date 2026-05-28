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

    //harness:criterion=c-input-did-toggle-favorite,c-input-did-toggle-favorites-filter,c-output-is-filtering-favorites,c-empty-favorites-title-exposed,c-no-persistence-dependency
    func testFavoritesProtocolSurfaceIsAvailableOnViewModel() {
        let viewModel: MoviesListViewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )

        XCTAssertFalse(viewModel.isFilteringFavorites.value)
        XCTAssertFalse(viewModel.emptyFavoritesTitle.isEmpty)
        XCTAssertFalse(viewModel.favoritesFilterAllTitle.isEmpty)
        XCTAssertFalse(viewModel.favoritesFilterFavoritesTitle.isEmpty)

        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavoritesFilter()

        XCTAssertTrue(viewModel.isFilteringFavorites.value)
    }

    //harness:criterion=c-filter-mode-default-all
    func testDefaultFilterModeIsAll() {
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )

        XCTAssertFalse(viewModel.isFilteringFavorites.value)
    }

    //harness:criterion=c-toggle-favorite-adds-id,c-item-viewmodel-has-is-favorite
    func testToggleFavoriteAddsID() {
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorite")
        ]))

        XCTAssertFalse(viewModel.items.value[0].isFavorite)

        viewModel.didToggleFavorite(at: 0)

        XCTAssertTrue(viewModel.items.value[0].isFavorite)
    }

    //harness:criterion=c-toggle-favorite-removes-id
    func testToggleFavoriteRemovesID() {
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorite")
        ]))

        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavorite(at: 0)

        XCTAssertFalse(viewModel.items.value[0].isFavorite)
    }

    //harness:criterion=c-toggle-favorite-is-identity-based
    func testToggleFavoriteIsIdentityBased() {
        let sharedID = "same-id"
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: sharedID, title: "first"),
            Movie.stub(id: sharedID, title: "second")
        ]))

        viewModel.didToggleFavorite(at: 0)

        XCTAssertTrue(viewModel.items.value[0].isFavorite)
        XCTAssertTrue(viewModel.items.value[1].isFavorite)
    }

    //harness:criterion=c-item-viewmodel-has-id,c-item-viewmodel-equatable
    func testItemViewModelExposesIDAndIncludesFavoriteStateInEquality() {
        let movie = Movie.stub(id: "movie-id")
        let notFavorite = MoviesListItemViewModel(movie: movie, isFavorite: false)
        let favorite = MoviesListItemViewModel(movie: movie, isFavorite: true)

        XCTAssertEqual(notFavorite.id, movie.id)
        XCTAssertNotEqual(notFavorite, favorite)
    }

    //harness:criterion=c-filter-mode-toggle-to-favorites
    func testToggleFilterToFavorites() {
        let favoriteMovie = Movie.stub(id: "favorite")
        let otherMovie = Movie.stub(id: "other")
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: [
            favoriteMovie,
            otherMovie
        ]))
        viewModel.didToggleFavorite(at: 0)

        viewModel.didToggleFavoritesFilter()

        XCTAssertTrue(viewModel.isFilteringFavorites.value)
        XCTAssertEqual(viewModel.items.value.map { $0.id }, [favoriteMovie.id])
    }

    //harness:criterion=c-filter-mode-toggle-back-to-all
    func testToggleFilterBackToAll() {
        let movies = [
            Movie.stub(id: "first"),
            Movie.stub(id: "second")
        ]
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: movies))

        viewModel.didToggleFavoritesFilter()
        viewModel.didToggleFavoritesFilter()

        XCTAssertFalse(viewModel.isFilteringFavorites.value)
        XCTAssertEqual(viewModel.items.value.map { $0.id }, movies.map { $0.id })
    }

    //harness:criterion=c-items-recomputed-on-favorite-change
    func testItemsRecomputedOnFavoriteChange() {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorite")
        ]))
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavoritesFilter()
        XCTAssertEqual(viewModel.items.value.count, 1)

        viewModel.didToggleFavorite(at: 0)

        XCTAssertTrue(viewModel.items.value.isEmpty)
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 0)
    }

    //harness:criterion=c-items-all-mode-shows-all
    func testItemsAllModeShowsAll() {
        let firstPageMovies = [
            Movie.stub(id: "1"),
            Movie.stub(id: "2"),
            Movie.stub(id: "3")
        ]
        let secondPageMovies = [
            Movie.stub(id: "4"),
            Movie.stub(id: "5")
        ]
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )

        viewModel.appendPage(MoviesPage(page: 1, totalPages: 2, movies: firstPageMovies))
        viewModel.appendPage(MoviesPage(page: 2, totalPages: 2, movies: secondPageMovies))

        XCTAssertEqual(
            viewModel.items.value.map { $0.id },
            (firstPageMovies + secondPageMovies).map { $0.id }
        )
    }

    //harness:criterion=c-items-favorites-mode-shows-only-favorites
    func testItemsFavoritesModeShowsOnlyFavorites() {
        let movies = [
            Movie.stub(id: "first"),
            Movie.stub(id: "second"),
            Movie.stub(id: "third")
        ]
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: movies))
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavorite(at: 2)

        viewModel.didToggleFavoritesFilter()

        XCTAssertEqual(viewModel.items.value.map { $0.id }, [movies[0].id, movies[2].id])
    }

    //harness:criterion=c-cached-page-all-mode
    func testCachedPageAllMode() {
        let cachedMovies = [
            Movie.stub(id: "cached-1"),
            Movie.stub(id: "cached-2"),
            Movie.stub(id: "cached-3")
        ]
        let freshMovies = [
            Movie.stub(id: "fresh-1"),
            Movie.stub(id: "fresh-2")
        ]
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )

        viewModel.appendPage(MoviesPage(page: 1, totalPages: 2, movies: cachedMovies))
        viewModel.appendPage(MoviesPage(page: 2, totalPages: 2, movies: freshMovies))

        XCTAssertEqual(viewModel.items.value.count, 5)
        XCTAssertEqual(
            viewModel.items.value.map { $0.id },
            (cachedMovies + freshMovies).map { $0.id }
        )
    }

    //harness:criterion=c-cached-page-favorites-mode
    func testCachedPageFavoritesMode() {
        let favoriteID = "favorite"
        let initialMovies = [
            Movie.stub(id: favoriteID, title: "initial favorite"),
            Movie.stub(id: "other", title: "other")
        ]
        let cachedMovies = [
            Movie.stub(id: "cached-other", title: "cached other"),
            Movie.stub(id: favoriteID, title: "cached favorite")
        ]
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 2, movies: initialMovies))
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavoritesFilter()

        viewModel.appendPage(MoviesPage(page: 2, totalPages: 2, movies: cachedMovies))

        XCTAssertEqual(viewModel.items.value.map { $0.id }, [favoriteID, favoriteID])
    }

    //harness:criterion=c-empty-favorites-state
    func testEmptyFavoritesState() {
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "first"),
            Movie.stub(id: "second")
        ]))

        viewModel.didToggleFavoritesFilter()

        XCTAssertTrue(viewModel.items.value.isEmpty)
    }

    //harness:criterion=c-selection-maps-filtered-index,c-existing-details-navigation-preserved
    func testSelectionMapsFavoritesFilterIndex() {
        let movies = [
            Movie.stub(id: "A"),
            Movie.stub(id: "B"),
            Movie.stub(id: "C")
        ]
        var selectedMovie: Movie?
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: SearchMoviesUseCaseMock(),
            actions: MoviesListViewModelActions(
                showMovieDetails: { selectedMovie = $0 },
                showMovieQueriesSuggestions: { _ in },
                closeMovieQueriesSuggestions: { }
            ),
            mainQueue: DispatchQueueTypeMock()
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: movies))
        viewModel.didToggleFavorite(at: 2)
        viewModel.didToggleFavoritesFilter()

        viewModel.didSelectItem(at: 0)

        XCTAssertEqual(selectedMovie, movies[2])
    }

    //harness:criterion=c-selection-maps-all-index,c-existing-details-navigation-preserved
    func testSelectionMapsAllIndex() {
        let movies = [
            Movie.stub(id: "A"),
            Movie.stub(id: "B"),
            Movie.stub(id: "C")
        ]
        var selectedMovie: Movie?
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: SearchMoviesUseCaseMock(),
            actions: MoviesListViewModelActions(
                showMovieDetails: { selectedMovie = $0 },
                showMovieQueriesSuggestions: { _ in },
                closeMovieQueriesSuggestions: { }
            ),
            mainQueue: DispatchQueueTypeMock()
        )
        viewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: movies))

        viewModel.didSelectItem(at: 2)

        XCTAssertEqual(selectedMovie, movies[2])
    }

    //harness:criterion=c-pagination-guard-unchanged
    func testPaginationGuardUnchanged() {
        assertDuplicateNextPageRequestsAreGuarded(isFilteringFavorites: false)
        assertDuplicateNextPageRequestsAreGuarded(isFilteringFavorites: true)
    }

    //harness:criterion=c-favorites-reset-on-new-search
    func testFavoritesResetOnNewSearch() {
        let allModeViewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        allModeViewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "all-mode")
        ]))

        allModeViewModel.resetPages()

        XCTAssertTrue(allModeViewModel.items.value.isEmpty)

        let favoritesModeViewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: SearchMoviesUseCaseMock()
        )
        favoritesModeViewModel.appendPage(MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorites-mode")
        ]))
        favoritesModeViewModel.didToggleFavorite(at: 0)
        favoritesModeViewModel.didToggleFavoritesFilter()

        favoritesModeViewModel.resetPages()

        XCTAssertTrue(favoritesModeViewModel.items.value.isEmpty)
    }

    private func assertDuplicateNextPageRequestsAreGuarded(
        isFilteringFavorites: Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, _ in }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        if isFilteringFavorites {
            viewModel.didToggleFavoritesFilter()
        }

        viewModel.didSearch(query: "query")
        viewModel.didLoadNextPage()
        viewModel.didLoadNextPage()

        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 1, file: file, line: line)
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
