import UIKit

final class MoviesListItemCell: UITableViewCell {

    static let reuseIdentifier = String(describing: MoviesListItemCell.self)
    static let height = CGFloat(130)

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!
    @IBOutlet private var overviewLabel: UILabel!
    @IBOutlet private var posterImageView: UIImageView!
    @IBOutlet private var favoriteButton: UIButton!

    var onFavoriteTapped: (() -> Void)?
    private var viewModel: MoviesListItemViewModel!
    private var posterImagesRepository: PosterImagesRepository?
    private var imageLoadTask: Cancellable? { willSet { imageLoadTask?.cancel() } }
    private let mainQueue: DispatchQueueType = DispatchQueue.main

    func fill(
        with viewModel: MoviesListItemViewModel,
        posterImagesRepository: PosterImagesRepository?
    ) {
        self.viewModel = viewModel
        self.posterImagesRepository = posterImagesRepository

        titleLabel.text = viewModel.title
        dateLabel.text = viewModel.releaseDate
        overviewLabel.text = viewModel.overview
        favoriteButton.isSelected = viewModel.isFavorite
        favoriteButton.accessibilityIdentifier = AccessibilityIdentifier.movieFavoriteButton
        favoriteButton.accessibilityLabel = String(
            format: NSLocalizedString(viewModel.isFavorite ? "Remove %@ from favorites" : "Add %@ to favorites", comment: ""),
            viewModel.title
        )
        favoriteButton.accessibilityValue = NSLocalizedString(viewModel.isFavorite ? "Favorited" : "Not favorited", comment: "")
        updatePosterImage(width: Int(posterImageView.imageSizeAfterAspectFit.scaledSize.width))
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        favoriteButton.setTitle(NSLocalizedString("Favorite", comment: ""), for: .normal)
        favoriteButton.setTitle(NSLocalizedString("Favorited", comment: ""), for: .selected)
        favoriteButton.setTitleColor(.lightGray, for: .normal)
        favoriteButton.setTitleColor(.orange, for: .selected)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onFavoriteTapped = nil
        imageLoadTask = nil
        posterImageView.image = nil
        favoriteButton.isSelected = false
        favoriteButton.accessibilityLabel = nil
        favoriteButton.accessibilityValue = nil
    }

    @IBAction private func favoriteButtonTapped(_ sender: UIButton) {
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
