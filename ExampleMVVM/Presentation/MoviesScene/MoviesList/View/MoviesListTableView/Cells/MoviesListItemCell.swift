import UIKit

final class MoviesListItemCell: UITableViewCell {

    static let reuseIdentifier = String(describing: MoviesListItemCell.self)
    static let height = CGFloat(130)

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!
    @IBOutlet private var overviewLabel: UILabel!
    @IBOutlet private var posterImageView: UIImageView!

    private let favoriteButton = UIButton(type: .system)
    private var viewModel: MoviesListItemViewModel!
    private var posterImagesRepository: PosterImagesRepository?
    private var imageLoadTask: Cancellable? { willSet { imageLoadTask?.cancel() } }
    private let mainQueue: DispatchQueueType = DispatchQueue.main
    var onFavoriteTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupFavoriteButton()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onFavoriteTapped = nil
        imageLoadTask = nil
        posterImageView.image = nil
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

    private func setupFavoriteButton() {
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.addTarget(self, action: #selector(didTapFavoriteButton), for: .touchUpInside)
        contentView.addSubview(favoriteButton)
        NSLayoutConstraint.activate([
            favoriteButton.topAnchor.constraint(equalTo: posterImageView.topAnchor),
            favoriteButton.trailingAnchor.constraint(equalTo: posterImageView.trailingAnchor),
            favoriteButton.widthAnchor.constraint(equalToConstant: 44),
            favoriteButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func updateFavoriteButton() {
        favoriteButton.isSelected = viewModel.isFavorite
        favoriteButton.accessibilityLabel = viewModel.isFavorite ?
            NSLocalizedString("Remove from Favorites", comment: "") :
            NSLocalizedString("Add to Favorites", comment: "")
        favoriteButton.accessibilityValue = viewModel.isFavorite ? "selected" : "not selected"
        if #available(iOS 13.0, *) {
            let imageName = viewModel.isFavorite ? "star.fill" : "star"
            favoriteButton.setImage(UIImage(systemName: imageName), for: .normal)
            favoriteButton.setTitle(nil, for: .normal)
            favoriteButton.tintColor = viewModel.isFavorite ? .systemYellow : .secondaryLabel
        } else {
            favoriteButton.setImage(nil, for: .normal)
            favoriteButton.setTitle(viewModel.isFavorite ? "★" : "☆", for: .normal)
            favoriteButton.tintColor = viewModel.isFavorite ? .orange : .gray
        }
    }

    @objc private func didTapFavoriteButton() {
        onFavoriteTapped?()
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
