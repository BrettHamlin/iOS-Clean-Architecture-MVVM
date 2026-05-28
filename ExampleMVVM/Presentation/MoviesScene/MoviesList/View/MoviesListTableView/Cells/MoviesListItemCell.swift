import UIKit

final class MoviesListItemCell: UITableViewCell {

    static let reuseIdentifier = String(describing: MoviesListItemCell.self)
    static let height = CGFloat(130)

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!
    @IBOutlet private var overviewLabel: UILabel!
    @IBOutlet private var posterImageView: UIImageView!
    @IBOutlet private(set) var favoriteButton: UIButton!

    var onFavoriteButtonTap: (() -> Void)?

    private var viewModel: MoviesListItemViewModel!
    private var posterImagesRepository: PosterImagesRepository?
    private var imageLoadTask: Cancellable? { willSet { imageLoadTask?.cancel() } }
    private let mainQueue: DispatchQueueType = DispatchQueue.main

    override func awakeFromNib() {
        super.awakeFromNib()
        setupFavoriteButton()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask = nil
        onFavoriteButtonTap = nil
    }

    func fill(
        with viewModel: MoviesListItemViewModel,
        posterImagesRepository: PosterImagesRepository?
    ) {
        setupFavoriteButton()
        self.viewModel = viewModel
        self.posterImagesRepository = posterImagesRepository

        titleLabel.text = viewModel.title
        dateLabel.text = viewModel.releaseDate
        overviewLabel.text = viewModel.overview
        updateFavoriteButton()
        updatePosterImage(width: Int(posterImageView.imageSizeAfterAspectFit.scaledSize.width))
    }

    private func setupFavoriteButton() {
        if favoriteButton == nil {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(button)
            favoriteButton = button
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                button.trailingAnchor.constraint(equalTo: posterImageView.leadingAnchor, constant: -8),
                button.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
                button.leadingAnchor.constraint(greaterThanOrEqualTo: dateLabel.trailingAnchor, constant: 8),
                button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
                button.heightAnchor.constraint(equalToConstant: 44)
            ])
        }

        favoriteButton.removeTarget(self, action: #selector(didTapFavoriteButton), for: .touchUpInside)
        favoriteButton.addTarget(self, action: #selector(didTapFavoriteButton), for: .touchUpInside)
        favoriteButton.accessibilityIdentifier = AccessibilityIdentifier.favoriteButton
        favoriteButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        favoriteButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func updateFavoriteButton() {
        favoriteButton.isSelected = viewModel.isFavorite
        favoriteButton.setTitle(
            viewModel.isFavorite ? NSLocalizedString("Favorited", comment: "") : NSLocalizedString("Favorite", comment: ""),
            for: .normal
        )
        favoriteButton.setTitleColor(viewModel.isFavorite ? .orange : tintColor, for: .normal)
        let accessibilityLabelFormat = viewModel.isFavorite ?
            NSLocalizedString("Remove movie from favorites", comment: "") :
            NSLocalizedString("Add movie to favorites", comment: "")
        favoriteButton.accessibilityLabel = String(format: accessibilityLabelFormat, viewModel.title)
        favoriteButton.accessibilityValue = viewModel.isFavorite ?
            NSLocalizedString("Favorited", comment: "") :
            NSLocalizedString("Not favorited", comment: "")
        favoriteButton.accessibilityTraits = viewModel.isFavorite ? [.button, .selected] : .button
    }

    @IBAction private func didTapFavoriteButton(_ sender: UIButton) {
        onFavoriteButtonTap?()
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
