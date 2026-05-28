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

    func test_whenViewModelIsCreated_thenFilterModeStartsInAll() {
        //harness:criterion=c-output-protocol-filter-mode-observable,c-filter-mode-enum-cases,c-default-filter-mode-is-all,c-xctest-style-given-when-then
        // given
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        let mainQueue = DispatchQueueTypeMock()

        // when
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        let output: MoviesListViewModelOutput = viewModel

        // then
        XCTAssertEqual(output.filterMode.value, .all)
        switch output.filterMode.value {
        case .all:
            break
        case .favorites:
            XCTFail("Expected default filter mode to be all")
        }
    }

    func test_whenFavoriteIsToggledInAllMode_thenItemFavoriteStateUpdatesAndEmits() {
        //harness:criterion=c-input-protocol-did-toggle-favorite,c-did-toggle-favorite-adds-id,c-did-toggle-favorite-removes-id,c-items-rederived-on-favorite-toggle,c-item-view-model-is-favorite-field,c-item-view-model-id-field,c-item-view-model-init-accepts-favorite-state,c-xctest-style-given-when-then
        // given
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorite-id", title: "favorite title")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "query")
        var emittedItems: [[MoviesListItemViewModel]] = []
        viewModel.items.observe(on: self) { items in
            emittedItems.append(items)
        }
        let input: MoviesListViewModelInput = viewModel

        // when
        input.didToggleFavorite(at: 0)

        // then
        XCTAssertEqual(viewModel.items.value.first?.id, "favorite-id")
        XCTAssertEqual(viewModel.items.value.first?.isFavorite, true)
        XCTAssertEqual(emittedItems.count, 2)
        XCTAssertEqual(emittedItems.last?.first?.isFavorite, true)

        // when
        input.didToggleFavorite(at: 0)

        // then
        XCTAssertEqual(viewModel.items.value.first?.isFavorite, false)
        XCTAssertEqual(emittedItems.count, 3)
        XCTAssertEqual(emittedItems.last?.first?.isFavorite, false)
    }

    func test_whenFavoriteFilterIsSelectedWithoutFavorites_thenItemsAreEmpty() {
        //harness:criterion=c-input-protocol-did-toggle-filter,c-filter-favorites-empty-when-no-favorites,c-items-rederived-on-filter-change,c-xctest-style-given-when-then
        // given
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "1"),
            Movie.stub(id: "2")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "query")
        let input: MoviesListViewModelInput = viewModel

        // when
        input.didToggleFilter()

        // then
        XCTAssertEqual(viewModel.filterMode.value, .favorites)
        XCTAssertTrue(viewModel.items.value.isEmpty)
    }

    func test_whenFilterIsToggled_thenFavoritesAndAllModesRederiveCurrentItems() {
        //harness:criterion=c-did-toggle-filter-switches-mode,c-filter-all-shows-all-items,c-filter-favorites-shows-only-favorited,c-items-rederived-on-filter-change,c-xctest-style-given-when-then
        // given
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "1"),
            Movie.stub(id: "2"),
            Movie.stub(id: "3")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFavorite(at: 2)

        // when
        viewModel.didToggleFilter()

        // then
        XCTAssertEqual(viewModel.filterMode.value, .favorites)
        XCTAssertEqual(viewModel.items.value.map(\.id), ["1", "3"])
        XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })

        // when
        viewModel.didToggleFilter()

        // then
        XCTAssertEqual(viewModel.filterMode.value, .all)
        XCTAssertEqual(viewModel.items.value.map(\.id), ["1", "2", "3"])
    }

    func test_whenFilterIsSetDirectly_thenItemsEmitForSelectedFilter() {
        //harness:criterion=c-input-protocol-did-toggle-filter,c-did-toggle-filter-switches-mode,c-items-rederived-on-filter-change,c-xctest-style-given-when-then
        // given
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "1"),
            Movie.stub(id: "2"),
            Movie.stub(id: "3")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 1)
        var emittedIDs: [[Movie.Identifier]] = []
        viewModel.items.observe(on: self) { items in
            emittedIDs.append(items.map(\.id))
        }
        let input: MoviesListViewModelInput = viewModel

        // when
        input.didSetFilter(.favorites)

        // then
        XCTAssertEqual(viewModel.filterMode.value, .favorites)
        XCTAssertEqual(viewModel.items.value.map(\.id), ["2"])
        XCTAssertEqual(emittedIDs.last, ["2"])

        // when
        input.didSetFilter(.all)

        // then
        XCTAssertEqual(viewModel.filterMode.value, .all)
        XCTAssertEqual(viewModel.items.value.map(\.id), ["1", "2", "3"])
        XCTAssertEqual(emittedIDs.last, ["1", "2", "3"])
    }

    func test_whenFavoriteIsRemovedWhileFavoritesFilterIsActive_thenFilteredItemsUpdateImmediately() {
        //harness:criterion=c-did-toggle-favorite-removes-id,c-items-rederived-on-favorite-toggle,c-filter-favorites-shows-only-favorited,c-xctest-style-given-when-then
        // given
        let page = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "unfavorited-id"),
            Movie.stub(id: "favorited-id")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFilter()
        var emittedItems: [[MoviesListItemViewModel]] = []
        viewModel.items.observe(on: self) { items in
            emittedItems.append(items)
        }

        // when
        viewModel.didToggleFavorite(at: 0)

        // then
        XCTAssertEqual(viewModel.filterMode.value, .favorites)
        XCTAssertTrue(viewModel.items.value.isEmpty)
        XCTAssertEqual(emittedItems.last?.count, 0)
    }

    func test_whenLoadingNextPageInAllMode_thenItemsContainAllMoviesAcrossPages() {
        //harness:criterion=c-append-page-all-filter-unaffected,c-filter-all-shows-all-items,c-xctest-style-given-when-then
        // given
        let page1 = MoviesPage(page: 1, totalPages: 2, movies: [
            Movie.stub(id: "1"),
            Movie.stub(id: "2")
        ])
        let page2 = MoviesPage(page: 2, totalPages: 2, movies: [
            Movie.stub(id: "3"),
            Movie.stub(id: "4")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(page1))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            completion(.success(page2))
        }

        // when
        viewModel.didLoadNextPage()

        // then
        XCTAssertEqual(viewModel.filterMode.value, .all)
        XCTAssertEqual(viewModel.items.value.map(\.id), ["1", "2", "3", "4"])
    }

    func test_whenLoadingNextPageInFavoritesMode_thenItemsContainOnlyFavoritesAcrossPages() {
        //harness:criterion=c-append-page-respects-active-filter,c-pagination-in-favorites-mode-correct,c-xctest-style-given-when-then
        // given
        let seedPage = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "1"),
            Movie.stub(id: "2"),
            Movie.stub(id: "3")
        ])
        let page1 = MoviesPage(page: 1, totalPages: 2, movies: [
            Movie.stub(id: "1"),
            Movie.stub(id: "2")
        ])
        let page2 = MoviesPage(page: 2, totalPages: 2, movies: [
            Movie.stub(id: "3"),
            Movie.stub(id: "4")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(seedPage))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "seed query")
        viewModel.didToggleFavorite(at: 2)
        viewModel.didToggleFilter()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(page1))
        }
        viewModel.didSearch(query: "query")
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            completion(.success(page2))
        }

        // when
        viewModel.didLoadNextPage()

        // then
        XCTAssertEqual(viewModel.filterMode.value, .favorites)
        XCTAssertEqual(viewModel.items.value.map(\.id), ["3"])
        XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })
    }

    func test_whenLoadingUnfavoritedNextPageInFavoritesMode_thenExistingFavoritesRemainFiltered() {
        //harness:criterion=c-append-page-respects-active-filter,c-pagination-in-favorites-mode-correct,c-xctest-style-given-when-then
        // given
        let page1 = MoviesPage(page: 1, totalPages: 2, movies: [
            Movie.stub(id: "favorite-id"),
            Movie.stub(id: "unfavorited-id")
        ])
        let page2 = MoviesPage(page: 2, totalPages: 2, movies: [
            Movie.stub(id: "new-unfavorited-id-1"),
            Movie.stub(id: "new-unfavorited-id-2")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 1)
            completion(.success(page1))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFilter()
        searchMoviesUseCaseMock._execute = { requestValue, _, completion in
            XCTAssertEqual(requestValue.page, 2)
            completion(.success(page2))
        }

        // when
        viewModel.didLoadNextPage()

        // then
        XCTAssertEqual(viewModel.filterMode.value, .favorites)
        XCTAssertEqual(viewModel.items.value.map(\.id), ["favorite-id"])
        XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })
    }

    func test_whenCachedAndFreshResultsArriveInFavoritesMode_thenBothRespectFilter() {
        //harness:criterion=c-cached-page-update-respects-filter,c-fresh-page-update-respects-filter,c-xctest-style-given-when-then
        // given
        let seedPage = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorite-id")
        ])
        let cachedPage = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorite-id"),
            Movie.stub(id: "cached-unfavorited-id")
        ])
        let freshPage = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "fresh-unfavorited-id"),
            Movie.stub(id: "favorite-id")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(seedPage))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "seed query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFilter()
        var cachedItems: [MoviesListItemViewModel] = []
        searchMoviesUseCaseMock._execute = { _, cached, completion in
            cached(cachedPage)
            cachedItems = viewModel.items.value
            completion(.success(freshPage))
        }

        // when
        viewModel.didSearch(query: "query")

        // then
        XCTAssertEqual(cachedItems.map(\.id), ["favorite-id"])
        XCTAssertTrue(cachedItems.allSatisfy { $0.isFavorite })
        XCTAssertEqual(viewModel.items.value.map(\.id), ["favorite-id"])
        XCTAssertTrue(viewModel.items.value.allSatisfy { $0.isFavorite })
    }

    func test_whenFreshResultReplacesCachedFavoriteWithNoFavoritedMovies_thenFavoritesFilterIsEmpty() {
        //harness:criterion=c-fresh-page-update-respects-filter,c-items-rederived-on-filter-change,c-xctest-style-given-when-then
        // given
        let seedPage = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorite-id")
        ])
        let cachedPage = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "favorite-id"),
            Movie.stub(id: "cached-unfavorited-id")
        ])
        let freshPage = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "fresh-unfavorited-id")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(seedPage))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "seed query")
        viewModel.didToggleFavorite(at: 0)
        viewModel.didToggleFilter()
        var cachedItems: [MoviesListItemViewModel] = []
        searchMoviesUseCaseMock._execute = { _, cached, completion in
            cached(cachedPage)
            cachedItems = viewModel.items.value
            completion(.success(freshPage))
        }

        // when
        viewModel.didSearch(query: "replacement query")

        // then
        XCTAssertEqual(cachedItems.map(\.id), ["favorite-id"])
        XCTAssertTrue(cachedItems.allSatisfy { $0.isFavorite })
        XCTAssertTrue(viewModel.items.value.isEmpty)
    }

    func test_whenFavoriteExistsAndNewSearchStarts_thenFavoriteStatePersistsForMatchingMovie() {
        //harness:criterion=c-favorite-ids-state-in-memory,c-favorite-ids-persist-across-search-reset,c-xctest-style-given-when-then
        // given
        let firstPage = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "persisted-id")
        ])
        let secondPage = MoviesPage(page: 1, totalPages: 1, movies: [
            Movie.stub(id: "new-id"),
            Movie.stub(id: "persisted-id")
        ])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(firstPage))
        }
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "first query")
        viewModel.didToggleFavorite(at: 0)
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(secondPage))
        }

        // when
        viewModel.didSearch(query: "second query")

        // then
        let matchingItem = viewModel.items.value.first { $0.id == "persisted-id" }
        XCTAssertEqual(matchingItem?.isFavorite, true)
    }

    func test_whenSelectingItemInFavoritesMode_thenCoordinatorReceivesDisplayedMovie() {
        //harness:criterion=c-did-select-item-indexes-displayed-items,c-xctest-style-given-when-then
        // given
        let movieA = Movie.stub(id: "A")
        let movieB = Movie.stub(id: "B")
        let movieC = Movie.stub(id: "C")
        let page = MoviesPage(page: 1, totalPages: 1, movies: [movieA, movieB, movieC])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        var selectedMovie: Movie?
        let actions = MoviesListViewModelActions(
            showMovieDetails: { selectedMovie = $0 },
            showMovieQueriesSuggestions: { _ in },
            closeMovieQueriesSuggestions: { }
        )
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: actions,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "query")
        viewModel.didToggleFavorite(at: 1)
        viewModel.didToggleFilter()

        // when
        viewModel.didSelectItem(at: 0)

        // then
        XCTAssertEqual(viewModel.items.value.map(\.id), ["B"])
        XCTAssertEqual(selectedMovie, movieB)
        XCTAssertNotEqual(selectedMovie, movieA)
    }

    func test_whenSelectingItemInAllMode_thenCoordinatorReceivesDisplayedMovie() {
        //harness:criterion=c-did-select-item-all-mode-correct,c-xctest-style-given-when-then
        // given
        let movieA = Movie.stub(id: "A")
        let movieB = Movie.stub(id: "B")
        let movieC = Movie.stub(id: "C")
        let page = MoviesPage(page: 1, totalPages: 1, movies: [movieA, movieB, movieC])
        let searchMoviesUseCaseMock = SearchMoviesUseCaseMock()
        searchMoviesUseCaseMock._execute = { _, _, completion in
            completion(.success(page))
        }
        var selectedMovie: Movie?
        let actions = MoviesListViewModelActions(
            showMovieDetails: { selectedMovie = $0 },
            showMovieQueriesSuggestions: { _ in },
            closeMovieQueriesSuggestions: { }
        )
        let mainQueue = DispatchQueueTypeMock()
        let viewModel = DefaultMoviesListViewModel(
            searchMoviesUseCase: searchMoviesUseCaseMock,
            actions: actions,
            mainQueue: mainQueue
        )
        viewModel.didSearch(query: "query")

        // when
        viewModel.didSelectItem(at: 1)

        // then
        XCTAssertEqual(viewModel.items.value[1].id, "B")
        XCTAssertEqual(selectedMovie, movieB)
    }

    func test_whenItemViewModelsHaveDifferentFavoriteState_thenTheyAreNotEqual() {
        //harness:criterion=c-item-view-model-equality-includes-is-favorite,c-xctest-style-given-when-then
        // given
        _ = DispatchQueueTypeMock()
        let movie = Movie.stub(id: "same-id")
        let unfavoritedItem = MoviesListItemViewModel(movie: movie, isFavorite: false)

        // when
        let favoritedItem = MoviesListItemViewModel(movie: movie, isFavorite: true)

        // then
        XCTAssertNotEqual(unfavoritedItem, favoritedItem)
    }

    func test_whenMoviesListViewLoads_thenFilterControlUsesLocalizedSegmentsAndAccessibilityIdentifier() {
        //harness:criterion=c-segment-control-present-in-list-vc,c-storyboard-accommodates-segment-control,c-localized-string-all-en,c-localized-string-favorites-en,c-localized-strings-es,c-accessibility-id-filter-control,c-xctest-style-given-when-then
        // given
        _ = DispatchQueueTypeMock()
        let viewModel = MoviesListViewModelMock()
        let viewController = MoviesListViewController.create(
            with: viewModel,
            posterImagesRepository: nil
        )

        // when
        viewController.loadViewIfNeeded()
        let segmentedControl = viewController.view.firstSubview(of: UISegmentedControl.self)

        // then
        XCTAssertEqual(segmentedControl?.numberOfSegments, 2)
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 0), NSLocalizedString("All", comment: ""))
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 1), NSLocalizedString("Favorites", comment: ""))
        XCTAssertEqual(segmentedControl?.accessibilityIdentifier, AccessibilityIdentifier.moviesListFilterControl)
        XCTAssertEqual(localizedString("All", language: "en"), "All")
        XCTAssertEqual(localizedString("Favorites", language: "en"), "Favorites")
        XCTAssertEqual(localizedString("All", language: "es"), "Todas")
        XCTAssertEqual(localizedString("Favorites", language: "es"), "Favoritas")
        XCTAssertEqual(localizedString("Favorite", language: "es"), "Favorita")
    }

    func test_whenFilterSegmentChanges_thenViewModelReceivesSelectedFilterMode() throws {
        //harness:criterion=c-segment-control-wired-to-did-set-filter,c-input-protocol-did-toggle-filter,c-xctest-style-given-when-then
        // given
        _ = DispatchQueueTypeMock()
        let viewModel = MoviesListViewModelMock()
        let viewController = MoviesListViewController.create(
            with: viewModel,
            posterImagesRepository: nil
        )
        viewController.loadViewIfNeeded()
        let segmentedControl = try XCTUnwrap(viewController.view.firstSubview(of: UISegmentedControl.self))

        // when
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.sendActions(for: .valueChanged)

        // then
        XCTAssertEqual(viewModel.setFilterModes, [.favorites])

        // when
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.sendActions(for: .valueChanged)

        // then
        XCTAssertEqual(viewModel.setFilterModes, [.favorites, .all])
    }

    func test_whenFilterModeEmits_thenFilterSegmentReflectsMode() throws {
        //harness:criterion=c-segment-control-observes-filter-mode,c-xctest-style-given-when-then
        // given
        _ = DispatchQueueTypeMock()
        let viewModel = MoviesListViewModelMock()
        let viewController = MoviesListViewController.create(
            with: viewModel,
            posterImagesRepository: nil
        )
        viewController.loadViewIfNeeded()
        let segmentedControl = try XCTUnwrap(viewController.view.firstSubview(of: UISegmentedControl.self))

        // when
        viewModel.filterMode.value = .favorites

        // then
        XCTAssertEqual(segmentedControl.selectedSegmentIndex, 1)

        // when
        viewModel.filterMode.value = .all

        // then
        XCTAssertEqual(segmentedControl.selectedSegmentIndex, 0)
    }

    func test_whenMovieCellIsDequeued_thenFavoriteButtonReflectsItemAndForwardsTap() throws {
        //harness:criterion=c-favorite-button-in-cell,c-cell-favorite-callback-forwarded,c-localized-string-favorite-a11y-en,c-accessibility-id-favorite-button,c-storyboard-accommodates-segment-control,c-xctest-style-given-when-then
        // given
        _ = DispatchQueueTypeMock()
        let movie = Movie.stub(id: "favorite-id", title: "Favorite Movie")
        let viewModel = MoviesListViewModelMock()
        viewModel.items.value = [
            MoviesListItemViewModel(movie: movie, isFavorite: true)
        ]
        let viewController = MoviesListViewController.create(
            with: viewModel,
            posterImagesRepository: nil
        )
        viewController.loadViewIfNeeded()
        let tableView = try XCTUnwrap(viewController.view.firstSubview(of: UITableView.self))

        // when
        let cell = tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 0, section: 0)
        )
        let favoriteButton = try XCTUnwrap(cell?.firstSubview(of: UIButton.self))
        favoriteButton.sendActions(for: .touchUpInside)

        // then
        XCTAssertTrue(favoriteButton.isSelected)
        XCTAssertEqual(favoriteButton.accessibilityIdentifier, AccessibilityIdentifier.movieFavoriteButton)
        XCTAssertEqual(favoriteButton.accessibilityValue, NSLocalizedString("Favorited", comment: ""))
        XCTAssertEqual(
            favoriteButton.accessibilityLabel,
            String(format: NSLocalizedString("Remove %@ from favorites", comment: ""), "Favorite Movie")
        )
        XCTAssertEqual(localizedString("Favorite", language: "en"), "Favorite")
        XCTAssertEqual(localizedString("Favorited", language: "en"), "Favorited")
        XCTAssertEqual(localizedString("Remove %@ from favorites", language: "en"), "Remove %@ from favorites")
        XCTAssertEqual(viewModel.toggleFavoriteIndexes, [0])
    }

    private func localizedString(_ key: String, language: String) -> String {
        for bundle in [Bundle.main, Bundle(for: MoviesListViewModelTests.self)] {
            guard let path = bundle.path(forResource: language, ofType: "lproj"),
                  let localizedBundle = Bundle(path: path) else { continue }
            return localizedBundle.localizedString(forKey: key, value: nil, table: nil)
        }
        XCTFail("Missing localized bundle for \(language)")
        return ""
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

private final class MoviesListViewModelMock: MoviesListViewModel {
    let items: Observable<[MoviesListItemViewModel]> = Observable([])
    let filterMode: Observable<MoviesListFilterMode> = Observable(.all)
    let loading: Observable<MoviesListViewModelLoading?> = Observable(.none)
    let query: Observable<String> = Observable("")
    let error: Observable<String> = Observable("")
    var isEmpty: Bool { items.value.isEmpty }
    let screenTitle = "Movies"
    let emptyDataTitle = "Search results"
    let errorTitle = "Error"
    let searchBarPlaceholder = "Search Movies"

    private(set) var setFilterModes: [MoviesListFilterMode] = []
    private(set) var toggleFavoriteIndexes: [Int] = []

    func viewDidLoad() { }
    func didLoadNextPage() { }
    func didSearch(query: String) { self.query.value = query }
    func didCancelSearch() { }
    func showQueriesSuggestions() { }
    func closeQueriesSuggestions() { }
    func didSelectItem(at index: Int) { }
    func didToggleFavorite(at index: Int) {
        toggleFavoriteIndexes.append(index)
    }
    func didToggleFilter() {
        didSetFilter(filterMode.value == .all ? .favorites : .all)
    }
    func didSetFilter(_ filterMode: MoviesListFilterMode) {
        setFilterModes.append(filterMode)
        self.filterMode.value = filterMode
    }
}

private extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let matchingView = self as? T {
            return matchingView
        }
        for subview in subviews {
            if let matchingView = subview.firstSubview(of: type) {
                return matchingView
            }
        }
        return nil
    }
}
