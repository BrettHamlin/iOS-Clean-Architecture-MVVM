import UIKit

final class MoviesListViewController: UIViewController, StoryboardInstantiable, Alertable {
    
    @IBOutlet private var contentView: UIView!
    @IBOutlet private var moviesListContainer: UIView!
    @IBOutlet private(set) var suggestionsListContainer: UIView!
    @IBOutlet private var searchBarContainer: UIView!
    @IBOutlet private var emptyDataLabel: UILabel!
    
    private var viewModel: MoviesListViewModel!
    private var posterImagesRepository: PosterImagesRepository?

    private var moviesTableViewController: MoviesListTableViewController?
    private var searchController = UISearchController(searchResultsController: nil)
    private(set) lazy var favoritesFilterControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [
            NSLocalizedString("All", comment: ""),
            NSLocalizedString("Favorites", comment: "")
        ])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(didChangeFavoritesFilter), for: .valueChanged)
        return control
    }()

    // MARK: - Lifecycle

    static func create(
        with viewModel: MoviesListViewModel,
        posterImagesRepository: PosterImagesRepository?
    ) -> MoviesListViewController {
        let view: MoviesListViewController
        if Bundle.main.path(forResource: defaultFileName, ofType: "storyboardc") != nil {
            let storyboard = UIStoryboard(name: defaultFileName, bundle: nil)
            view = storyboard.instantiateInitialViewController() as? MoviesListViewController
                ?? MoviesListViewController()
        } else {
            view = MoviesListViewController()
        }
        view.viewModel = viewModel
        view.posterImagesRepository = posterImagesRepository
        return view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupProgrammaticViewIfNeeded()
        setupViews()
        setupBehaviours()
        bind(to: viewModel)
        viewModel.viewDidLoad()
    }

    private func bind(to viewModel: MoviesListViewModel) {
        viewModel.items.observe(on: self) { [weak self] _ in self?.updateItems() }
        viewModel.loading.observe(on: self) { [weak self] in self?.updateLoading($0) }
        viewModel.query.observe(on: self) { [weak self] in self?.updateSearchQuery($0) }
        viewModel.error.observe(on: self) { [weak self] in self?.showError($0) }
        viewModel.favoriteFilterActive.observe(on: self) { [weak self] in self?.updateFavoritesFilter($0) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchController.isActive = false
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == String(describing: MoviesListTableViewController.self),
            let destinationVC = segue.destination as? MoviesListTableViewController {
            moviesTableViewController = destinationVC
            moviesTableViewController?.viewModel = viewModel
            moviesTableViewController?.posterImagesRepository = posterImagesRepository
        }
    }

    // MARK: - Private

    private func setupProgrammaticViewIfNeeded() {
        guard contentView == nil else { return }

        contentView = view
        moviesListContainer = UIView()
        suggestionsListContainer = UIView()
        searchBarContainer = UIView()
        emptyDataLabel = UILabel()

        [searchBarContainer, moviesListContainer, suggestionsListContainer, emptyDataLabel].forEach {
            guard let subview = $0 else { return }
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            searchBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBarContainer.heightAnchor.constraint(equalToConstant: 56),

            emptyDataLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyDataLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            moviesListContainer.topAnchor.constraint(equalTo: searchBarContainer.bottomAnchor),
            moviesListContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            moviesListContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            moviesListContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            suggestionsListContainer.topAnchor.constraint(equalTo: searchBarContainer.bottomAnchor),
            suggestionsListContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionsListContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionsListContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupViews() {
        title = viewModel.screenTitle
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: favoritesFilterControl)
        emptyDataLabel.text = viewModel.emptyDataTitle
        setupSearchController()
    }

    private func setupBehaviours() {
        addBehaviors([BackButtonEmptyTitleNavigationBarBehavior(),
                      BlackStyleNavigationBarBehavior()])
    }

    private func updateItems() {
        moviesTableViewController?.reload()
    }

    private func updateLoading(_ loading: MoviesListViewModelLoading?) {
        emptyDataLabel.isHidden = true
        moviesListContainer.isHidden = true
        suggestionsListContainer.isHidden = true
        LoadingView.hide()

        switch loading {
        case .fullScreen: LoadingView.show()
        case .nextPage: moviesListContainer.isHidden = false
        case .none:
            moviesListContainer.isHidden = viewModel.isEmpty
            emptyDataLabel.isHidden = !viewModel.isEmpty
        }

        moviesTableViewController?.updateLoading(loading)
        updateQueriesSuggestions()
    }

    private func updateQueriesSuggestions() {
        guard searchController.searchBar.isFirstResponder else {
            viewModel.closeQueriesSuggestions()
            return
        }
        viewModel.showQueriesSuggestions()
    }

    private func updateSearchQuery(_ query: String) {
        searchController.isActive = false
        searchController.searchBar.text = query
    }

    private func showError(_ error: String) {
        guard !error.isEmpty else { return }
        showAlert(title: viewModel.errorTitle, message: error)
    }

    private func updateFavoritesFilter(_ isActive: Bool) {
        favoritesFilterControl.selectedSegmentIndex = isActive ? 1 : 0
    }

    @objc private func didChangeFavoritesFilter() {
        let shouldActivateFilter = favoritesFilterControl.selectedSegmentIndex == 1
        guard viewModel.favoriteFilterActive.value != shouldActivateFilter else { return }
        viewModel.didToggleFavoritesFilter()
    }
}

// MARK: - Search Controller

extension MoviesListViewController {
    private func setupSearchController() {
        searchController.delegate = self
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = viewModel.searchBarPlaceholder
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.translatesAutoresizingMaskIntoConstraints = true
        searchController.searchBar.barStyle = .black
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.frame = searchBarContainer.bounds
        searchController.searchBar.autoresizingMask = [.flexibleWidth]
        searchBarContainer.addSubview(searchController.searchBar)
        definesPresentationContext = true
        if #available(iOS 13.0, *) {
            searchController.searchBar.searchTextField.accessibilityIdentifier = AccessibilityIdentifier.searchField
        }
    }
}

extension MoviesListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, !searchText.isEmpty else { return }
        searchController.isActive = false
        viewModel.didSearch(query: searchText)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        viewModel.didCancelSearch()
    }
}

extension MoviesListViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        updateQueriesSuggestions()
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        updateQueriesSuggestions()
    }

    func didDismissSearchController(_ searchController: UISearchController) {
        updateQueriesSuggestions()
    }
}
