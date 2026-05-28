import UIKit

final class MoviesListItemCell: UITableViewCell {

    static let reuseIdentifier = String(describing: MoviesListItemCell.self)
    static let height = CGFloat(130)

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!
    @IBOutlet private var overviewLabel: UILabel!
    @IBOutlet private var posterImageView: UIImageView!

    private var viewModel: MoviesListItemViewModel!
    private var posterImagesRepository: PosterImagesRepository?
    private var imageLoadTask: Cancellable? { willSet { imageLoadTask?.cancel() } }
    private let mainQueue: DispatchQueueType = DispatchQueue.main
    var onFavoriteToggle: (() -> Void)?

    override func prepareForReuse() {
        super.prepareForReuse()
        onFavoriteToggle = nil
        accessoryView = nil
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
        updateFavoriteIndicator()
        updatePosterImage(width: Int(posterImageView.imageSizeAfterAspectFit.scaledSize.width))
    }

    private func updateFavoriteIndicator() {
        let favoriteButton = UIButton(type: .system)
        favoriteButton.setTitle(viewModel.isFavorite ? "★" : "☆", for: .normal)
        favoriteButton.titleLabel?.font = UIFont.systemFont(ofSize: 28)
        let accessibilityFormat = viewModel.isFavorite ?
            NSLocalizedString("Remove %@ from favorites", comment: "") :
            NSLocalizedString("Add %@ to favorites", comment: "")
        favoriteButton.accessibilityLabel = String(format: accessibilityFormat, viewModel.title)
        if viewModel.isFavorite {
            favoriteButton.accessibilityTraits.insert(.selected)
        } else {
            favoriteButton.accessibilityTraits.remove(.selected)
        }
        favoriteButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        favoriteButton.addTarget(self, action: #selector(didTapFavoriteButton), for: .touchUpInside)
        accessoryView = favoriteButton
    }

    @objc private func didTapFavoriteButton() {
        onFavoriteToggle?()
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
