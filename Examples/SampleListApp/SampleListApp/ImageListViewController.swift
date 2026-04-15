//
//  ImageListViewController.swift
//  SampleListApp
//
//  Created by 김동현 on 4/15/26.
//

import UIKit

final class ImageListViewController: UITableViewController {
    private let section: ImageListSection
    
    init(section: ImageListSection) {
        self.section = section
        super.init(style: .plain)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = section.title
        tableView.rowHeight = 96
        tableView.separatorStyle = .none
        tableView.register(
            ImageListCell.self,
            forCellReuseIdentifier: ImageListCell.reuseIdentifier
        )
    }
    
    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        self.section.items.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ImageListCell.reuseIdentifier,
            for: indexPath
        )
        
        guard let imageListCell = cell as? ImageListCell else {
            return cell
        }
        
        imageListCell.configure(with: section.items[indexPath.row])
        return imageListCell
    }
}
