import UIKit

final class MoviesListItemCell: UITableViewCell {

    static let reuseIdentifier = String(describing: MoviesListItemCell.self)
    static let height = CGFloat(130)

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!
    @IBOutlet private var overviewLabel: UILabel!
    @IBOutlet private var posterImageView: UIImageView!
    @IBOutlet private var favoriteButton: UIButton!

    var onFavoriteTap: (() -> Void)?
    private var viewModel: MoviesListItemViewModel!
    private var posterImagesRepository: PosterImagesRepository?
    private var imageLoadTask: Cancellable? { willSet { imageLoadTask?.cancel() } }
    private let mainQueue: DispatchQueueType = DispatchQueue.main

    override func awakeFromNib() {
        super.awakeFromNib()
        configureDefaultFavoriteButton()
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

    @IBAction private func didTapFavoriteButton(_ sender: UIButton) {
        onFavoriteTap?()
    }

    private func configureDefaultFavoriteButton() {
        favoriteButton.accessibilityLabel = NSLocalizedString("Favorite", comment: "")
        if #available(iOS 13.0, *) {
            favoriteButton.setImage(UIImage(systemName: "star"), for: .normal)
            favoriteButton.setTitle(nil, for: .normal)
        } else {
            favoriteButton.setTitle("☆", for: .normal)
        }
    }

    private func updateFavoriteButton() {
        favoriteButton.isSelected = viewModel.isFavorite
        let accessibilityLabelFormat = viewModel.isFavorite ?
            NSLocalizedString("Remove %@ from favorites", comment: "") :
            NSLocalizedString("Add %@ to favorites", comment: "")
        favoriteButton.accessibilityLabel = String(format: accessibilityLabelFormat, viewModel.title)
        favoriteButton.accessibilityValue = viewModel.isFavorite ?
            NSLocalizedString("Selected", comment: "") :
            NSLocalizedString("Not Selected", comment: "")
        favoriteButton.accessibilityTraits = .button
        if viewModel.isFavorite {
            favoriteButton.accessibilityTraits.insert(.selected)
        }
        if #available(iOS 13.0, *) {
            let imageName = viewModel.isFavorite ? "star.fill" : "star"
            favoriteButton.setImage(UIImage(systemName: imageName), for: .normal)
            favoriteButton.setTitle(nil, for: .normal)
        } else {
            favoriteButton.setTitle(viewModel.isFavorite ? "★" : "☆", for: .normal)
        }
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
