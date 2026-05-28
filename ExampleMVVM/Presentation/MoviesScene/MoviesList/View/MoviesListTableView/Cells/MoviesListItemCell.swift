import UIKit

final class MoviesListItemCell: UITableViewCell {

    static let reuseIdentifier = String(describing: MoviesListItemCell.self)
    static let height = CGFloat(130)

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!
    @IBOutlet private var overviewLabel: UILabel!
    @IBOutlet private var posterImageView: UIImageView!
    private(set) var favoriteButton = UIButton(type: .system)

    private var viewModel: MoviesListItemViewModel!
    private var posterImagesRepository: PosterImagesRepository?
    private var imageLoadTask: Cancellable? { willSet { imageLoadTask?.cancel() } }
    private let mainQueue: DispatchQueueType = DispatchQueue.main
    var onFavoriteButtonTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupFavoriteButton()
    }

    func fill(
        with viewModel: MoviesListItemViewModel,
        posterImagesRepository: PosterImagesRepository?
    ) {
        self.viewModel = viewModel
        self.posterImagesRepository = posterImagesRepository

        titleLabel.text = viewModel.title
        dateLabel.text = viewModel.releaseDate
        overviewLabel.text = viewModel.overview
        updateFavoriteButton()
        updatePosterImage(width: Int(posterImageView.imageSizeAfterAspectFit.scaledSize.width))
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onFavoriteButtonTapped = nil
    }

    private func setupFavoriteButton() {
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.addTarget(self, action: #selector(didTapFavoriteButton), for: .touchUpInside)
        favoriteButton.accessibilityLabel = NSLocalizedString("Favorites", comment: "")
        contentView.addSubview(favoriteButton)
        NSLayoutConstraint.activate([
            favoriteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            favoriteButton.widthAnchor.constraint(equalToConstant: 44),
            favoriteButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func updateFavoriteButton() {
        if #available(iOS 13.0, *) {
            favoriteButton.setImage(UIImage(systemName: viewModel.isFavorite ? "star.fill" : "star"), for: .normal)
            favoriteButton.setTitle(nil, for: .normal)
        } else {
            favoriteButton.setImage(nil, for: .normal)
            favoriteButton.setTitle(viewModel.isFavorite ? "★" : "☆", for: .normal)
        }
    }

    @objc private func didTapFavoriteButton() {
        onFavoriteButtonTapped?()
    }

    private func updatePosterImage(width: Int) {
        posterImageView.image = nil
        guard let posterImagePath = viewModel.posterImagePath else { return }

        imageLoadTask = posterImagesRepository?.fetchImage(
            with: posterImagePath,
            width: width
        ) { [weak self] result in
            self?.mainQueue.async {
                guard self?.viewModel.posterImagePath == posterImagePath else { return }
                if case let .success(data) = result {
                    self?.posterImageView.image = UIImage(data: data)
                }
                self?.imageLoadTask = nil
            }
        }
    }
}
