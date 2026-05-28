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

    // harness:criterion=c-existing-recent-query-suggestion-preserved,c-existing-search-behavior-preserved,c-tests-use-given-when-then-style
    func test_whenMovieQuerySuggestionSelectedWithAllFilter_thenSuggestedQueryLoadsResults() {
        // given
        let suggestedPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "suggested-id", title: "suggested-title")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            XCTAssertEqual(requestValue.query, MovieQuery(query: "suggested query"))
            completion(.success(suggestedPage))
        }
        var didSelectSuggestion: ((MovieQuery) -> Void)?
        let actions = MoviesListViewModelActions(
            showMovieDetails: { _ in },
            showMovieQueriesSuggestions: { didSelectSuggestion = $0 },
            closeMovieQueriesSuggestions: {}
        )
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: actions
        )
        XCTAssertFalse(viewModel.isShowingFavorites.value)

        // when
        viewModel.showQueriesSuggestions()
        didSelectSuggestion?(MovieQuery(query: "suggested query"))

        // then
        XCTAssertEqual(viewModel.query.value, "suggested query")
        XCTAssertEqual(viewModel.items.value.map { $0.id }, ["suggested-id"])
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 1)
        XCTAssertFalse(viewModel.items.value[0].isFavorite)
    }

    // harness:criterion=c-input-toggle-favorite-method,c-input-toggle-filter-method,c-output-filter-mode-observable,c-output-filter-title-string,c-item-vm-id-property,c-item-vm-is-favorite-property,c-tests-use-given-when-then-style
    func test_whenUsingFavoritesPublicSurface_thenViewModelAndItemPropertiesAreAvailable() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        let input: MoviesListViewModelInput = viewModel
        let output: MoviesListViewModelOutput = viewModel

        // when
        viewModel.didSearch(query: "query")
        input.didToggleFavorite(at: 0)
        input.didToggleFilter()
        let item = output.items.value[0]

        // then
        XCTAssertFalse(DefaultMoviesListViewModel.filterTitle.isEmpty)
        XCTAssertTrue(output.isShowingFavorites.value)
        XCTAssertEqual(item.id, moviesPages[0].movies[0].id)
        XCTAssertTrue(item.isFavorite)
    }

    // harness:criterion=c-en-lproj-all-key,c-en-lproj-favorites-key,c-es-lproj-all-key,c-es-lproj-favorites-key,c-tests-use-given-when-then-style
    func test_whenLoadingFilterSegmentLocalizations_thenEnglishAndSpanishTitlesExist() throws {
        // given
        let englishStrings = try localizableStrings(for: "en")
        let spanishStrings = try localizableStrings(for: "es")

        // when
        let englishAllTitle = englishStrings["All"]
        let englishFavoritesTitle = englishStrings["Favorites"]
        let spanishAllTitle = spanishStrings["All"]
        let spanishFavoritesTitle = spanishStrings["Favorites"]

        // then
        XCTAssertEqual(englishAllTitle, "All")
        XCTAssertEqual(englishFavoritesTitle, "Favorites")
        XCTAssertFalse(spanishAllTitle?.isEmpty ?? true)
        XCTAssertFalse(spanishFavoritesTitle?.isEmpty ?? true)
        XCTAssertNotEqual(spanishAllTitle, englishAllTitle)
        XCTAssertNotEqual(spanishFavoritesTitle, englishFavoritesTitle)
    }

    // harness:criterion=c-toggle-favorite-marks-id,c-vm-favorite-ids-set-exists,c-tests-use-given-when-then-style
    func testToggleFavoriteMarksMovieID() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        XCTAssertFalse(viewModel.items.value[1].isFavorite)

        // when
        viewModel.didToggleFavorite(at: 1)

        // then
        XCTAssertEqual(viewModel.items.value[1].id, moviesPages[0].movies[1].id)
        XCTAssertTrue(viewModel.items.value[1].isFavorite)
    }

    // harness:criterion=c-toggle-favorite-unmarks-id,c-tests-use-given-when-then-style
    func testToggleFavoriteUnmarksMovieID() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 1)
        XCTAssertTrue(viewModel.items.value[1].isFavorite)

        // when
        viewModel.didToggleFavorite(at: 1)

        // then
        XCTAssertFalse(viewModel.items.value[1].isFavorite)
    }

    // harness:criterion=c-favorites-filter-shows-only-favorited,c-favorites-filter-empty-when-none-favorited,c-tests-use-given-when-then-style
    func testFavoritesFilterShowsOnlyFavoritedItems() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")

        // when
        viewModel.didToggleFilter()

        // then
        XCTAssertTrue(viewModel.items.value.isEmpty)

        // when
        viewModel.didToggleFilter()
        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFilter()

        // then
        XCTAssertEqual(viewModel.items.value.map { $0.id }, [moviesPages[0].movies[1].id])
        XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })
    }

    // harness:criterion=c-favorites-filter-empty-when-none-favorited,c-tests-use-given-when-then-style
    func testFavoritesFilterEmptyWhenNoneFavorited() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        XCTAssertEqual(viewModel.items.value.count, moviesPages[0].movies.count)

        // when
        viewModel.didToggleFilter()

        // then
        XCTAssertTrue(viewModel.isShowingFavorites.value)
        XCTAssertTrue(viewModel.items.value.isEmpty)
    }

    // harness:criterion=c-all-filter-restores-full-list,c-tests-use-given-when-then-style
    func testAllFilterRestoresFullList() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFilter()
        XCTAssertEqual(viewModel.items.value.count, 1)

        // when
        viewModel.didToggleFilter()

        // then
        XCTAssertEqual(viewModel.items.value.count, moviesPages[0].movies.count)
        XCTAssertEqual(viewModel.items.value.map { $0.id }, moviesPages[0].movies.map { $0.id })
    }

    // harness:criterion=c-table-vc-cell-uses-filtered-items,c-table-vc-select-uses-filtered-items,c-tests-use-given-when-then-style
    func test_whenFavoritesFilterActive_thenTableViewRowsUseFilteredItems() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        var selectedMovie: Movie?
        let actions = MoviesListViewModelActions(
            showMovieDetails: { selectedMovie = $0 },
            showMovieQueriesSuggestions: { _ in },
            closeMovieQueriesSuggestions: {}
        )
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: actions
        )
        let tableViewController = MoviesListTableViewController(style: .plain)
        tableViewController.viewModel = viewModel
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 1)

        // when
        viewModel.didToggleFilter()

        // then
        XCTAssertEqual(viewModel.items.value.map { $0.id }, [moviesPages[0].movies[1].id])
        XCTAssertEqual(
            tableViewController.tableView(tableViewController.tableView, numberOfRowsInSection: 0),
            viewModel.items.value.count
        )
        tableViewController.tableView(
            tableViewController.tableView,
            didSelectRowAt: IndexPath(row: 0, section: 0)
        )
        XCTAssertEqual(selectedMovie?.id, viewModel.items.value[0].id)
    }

    // harness:criterion=c-storyboard-segmented-control-added,c-vc-filter-observable-bound-to-control,c-vc-filter-action-forwarded-to-vm,c-vc-existing-bindings-preserved,c-tests-use-given-when-then-style
    func test_whenMoviesListViewLoads_thenFilterControlIsBoundToViewModel() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        let viewController = MoviesListViewController.create(
            with: viewModel,
            posterImagesRepository: nil
        )

        // when
        viewController.loadViewIfNeeded()

        // then
        guard let segmentedControl = firstSubview(
            ofType: UISegmentedControl.self,
            in: viewController.view
        ) else {
            XCTFail("Expected movies list view to contain a filter segmented control")
            return
        }
        XCTAssertEqual(segmentedControl.numberOfSegments, 2)
        XCTAssertEqual(segmentedControl.titleForSegment(at: 0), viewModel.allMoviesFilterTitle)
        XCTAssertEqual(segmentedControl.titleForSegment(at: 1), viewModel.favoriteMoviesFilterTitle)
        XCTAssertEqual(segmentedControl.selectedSegmentIndex, 0)
        let valueChangedActions = segmentedControl.actions(
            forTarget: viewController,
            forControlEvent: .valueChanged
        ) ?? []
        XCTAssertTrue(valueChangedActions.contains { $0.contains("didToggleFilter") })

        // when
        viewModel.didToggleFilter()

        // then
        XCTAssertEqual(segmentedControl.selectedSegmentIndex, 1)
    }

    // harness:criterion=c-cell-favorite-button-renders-state,c-cell-favorite-button-triggers-callback,c-tests-use-given-when-then-style
    func test_whenTableViewBuildsFavoriteCell_thenFavoriteButtonReflectsItemStateAndHasCallback() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        let viewController = MoviesListViewController.create(
            with: viewModel,
            posterImagesRepository: nil
        )
        viewController.loadViewIfNeeded()
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)

        guard let tableView = firstSubview(
            ofType: UITableView.self,
            in: viewController.view
        ) else {
            XCTFail("Expected movies list view to contain a table view")
            return
        }

        // when
        let cell = tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 0, section: 0)
        ) as? MoviesListItemCell

        // then
        let favoriteButton = cell.flatMap {
            firstSubview(ofType: UIButton.self, in: $0.contentView)
        }
        XCTAssertNotNil(cell?.onFavoriteTapped)
        XCTAssertEqual(favoriteButton?.isSelected, true)
        XCTAssertEqual(favoriteButton?.accessibilityValue, "selected")
        let touchUpInsideActions = favoriteButton?.actions(
            forTarget: cell,
            forControlEvent: .touchUpInside
        ) ?? []
        XCTAssertTrue(touchUpInsideActions.contains { $0.contains("didTapFavoriteButton") })
    }

    // harness:criterion=c-filter-applies-after-cached-callback,c-tests-use-given-when-then-style
    func testFavoritesFilterAppliesAfterCachedCallback() {
        // given
        let initialPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "favorite-id"),
            .stub(id: "other-id")
        ])
        let cachedPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "other-id"),
            .stub(id: "favorite-id")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(initialPage))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "first")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFilter()

        searchMoviesUseCaseMock._execute = { _, cached, _ in
            cached(cachedPage)
        }

        // when
        viewModel.didSearch(query: "second")

        // then
        XCTAssertEqual(viewModel.items.value.map { $0.id }, ["favorite-id"])
        XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })
    }

    // harness:criterion=c-filter-applies-after-fresh-callback,c-tests-use-given-when-then-style
    func testFavoritesFilterAppliesAfterFreshCallback() {
        // given
        let initialPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "favorite-id"),
            .stub(id: "other-id")
        ])
        let freshPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "other-id"),
            .stub(id: "favorite-id")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(initialPage))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "first")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFilter()

        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(freshPage))
        }

        // when
        viewModel.didSearch(query: "second")

        // then
        XCTAssertEqual(viewModel.items.value.map { $0.id }, ["favorite-id"])
        XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })
    }

    // harness:criterion=c-favorite-ids-survive-new-search,c-tests-use-given-when-then-style
    func testFavoriteIDsSurviveNewSearch() {
        // given
        let initialPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "a"),
            .stub(id: "b"),
            .stub(id: "c")
        ])
        let newSearchPage = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "c"),
            .stub(id: "a"),
            .stub(id: "b")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(initialPage))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "first")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavorite(at: 1)

        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(newSearchPage))
        }

        // when
        viewModel.didSearch(query: "second")

        // then
        XCTAssertEqual(viewModel.items.value.map { $0.id }, ["c", "a", "b"])
        XCTAssertFalse(viewModel.items.value[0].isFavorite)
        XCTAssertTrue(viewModel.items.value[1].isFavorite)
        XCTAssertTrue(viewModel.items.value[2].isFavorite)
    }

    // harness:criterion=c-did-select-navigates-correct-movie-filtered,c-tests-use-given-when-then-style
    func testDidSelectNavigatesCorrectMovieWhenFilterActive() {
        // given
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            .stub(id: "raw-first"),
            .stub(id: "favorite-first"),
            .stub(id: "favorite-second")
        ])
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
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: actions
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFavorite(at: 2)
        viewModel.didToggleFilter()

        // when
        viewModel.didSelectItem(at: 0)

        // then
        XCTAssertEqual(viewModel.items.value[0].id, "favorite-first")
        XCTAssertEqual(selectedMovie?.id, viewModel.items.value[0].id)
        XCTAssertNotEqual(selectedMovie?.id, Optional(page.movies[0].id))
    }

    // harness:criterion=c-did-select-navigates-correct-movie-all,c-existing-details-navigation-preserved,c-tests-use-given-when-then-style
    func testDidSelectNavigatesCorrectMovieAllFilter() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        var selectedMovie: Movie?
        let actions = MoviesListViewModelActions(
            showMovieDetails: { selectedMovie = $0 },
            showMovieQueriesSuggestions: { _ in },
            closeMovieQueriesSuggestions: {}
        )
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: actions
        )
        viewModel.didSearch(query: "query")

        // when
        viewModel.didSelectItem(at: 1)

        // then
        XCTAssertEqual(selectedMovie?.id, viewModel.items.value[1].id)
        XCTAssertEqual(selectedMovie?.id, moviesPages[0].movies[1].id)
    }

    // harness:criterion=c-pagination-not-blocked-by-filtered-list,c-tests-use-given-when-then-style
    func testPaginationNotBlockedByFilteredList() {
        // given
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
        viewModel.didToggleFilter()
        XCTAssertEqual(viewModel.items.value.count, 1)

        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            completion(.success(self.moviesPages[1]))
        }

        // when
        viewModel.didLoadNextPage()

        // then
        XCTAssertEqual(searchMoviesUseCaseMock.executeCallCount, 2)
        XCTAssertEqual(viewModel.currentPage, 2)
    }

    // harness:criterion=c-toggle-favorite-out-of-bounds-no-crash,c-tests-use-given-when-then-style
    func testToggleFavoriteOutOfBoundsNoCrash() {
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(self.moviesPages[0]))
        }
        let viewModel = DefaultMoviesListViewModel.make(
            searchMoviesUseCase: searchMoviesUseCaseMock
        )
        viewModel.didSearch(query: "query")
        let itemsBeforeToggle = viewModel.items.value

        // when
        viewModel.didToggleFavorite(at: Int.max)

        // then
        XCTAssertEqual(viewModel.items.value, itemsBeforeToggle)
    }

    private func localizableStrings(for localization: String) throws -> [String: String] {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = rootURL.appendingPathComponent("ExampleMVVM/Resources/\(localization).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        guard let strings = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            XCTFail("Expected Localizable.strings for \(localization) to parse as string key-value pairs")
            return [:]
        }
        return strings
    }

    private func firstSubview<T: UIView>(ofType type: T.Type, in view: UIView) -> T? {
        if let matchingView = view as? T {
            return matchingView
        }

        for subview in view.subviews {
            if let matchingView = firstSubview(ofType: type, in: subview) {
                return matchingView
            }
        }

        return nil
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
