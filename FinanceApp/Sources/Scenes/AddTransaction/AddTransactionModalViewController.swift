//
//  AddTransactionViewController.swift
//  FinanceApp
//
//  Created by Arthur Rios on 20/05/25.
//

import Foundation
import UIKit

final class AddTransactionModalViewController: UIViewController {
    let viewModel: AddTransactionModalViewModel
    let contentView: AddTransactionModalView
    weak var flowDelegate: AddTransactionModalFlowDelegate?
    
    init(contentView: AddTransactionModalView, flowDelegate: AddTransactionModalFlowDelegate, viewModel: AddTransactionModalViewModel) {
        self.contentView = contentView
        self.flowDelegate = flowDelegate
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
         
        contentView.delegate = self
        contentView.incomeSelectorButton.delegate = self
        contentView.expenseSelectorButton.delegate = self
                
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startKeyboardObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopKeyboardObservers()
    }
    
    private func setupView() {
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        setupGesture(viewTapped: blurEffectView)
        
        view.addSubview(blurEffectView)
        view.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        contentView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.56).isActive = true
    }
    
    private func setupGesture(viewTapped: UIView) {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissModal))
        viewTapped.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc
    private func dismissModal() {
        dismiss(animated: true)
    }
    
    func animateShow() {
        view.layoutIfNeeded()
        contentView.transform = CGAffineTransform(translationX: 0, y: contentView.frame.height)
        UIView.animate(withDuration: 0.3, animations: {
            self.contentView.transform = .identity
            self.view.layoutIfNeeded()
        })
    }
}

extension AddTransactionModalViewController: AddTransactionModalViewDelegate, TransactionTypeSelectorDelegate {
    func handleError(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let retryAction = UIAlertAction(title: "alert.ok".localized, style: .default)
        alertController.addAction(retryAction)
        self.present(alertController, animated: true)
    }
    
    func sendTransactionData(title: String, amount: Int, date: String, category: String, transactionType: String) {
        let result = viewModel.addTransaction(title: title, amount: amount, dateString: date, categoryKey: category, typeRaw: transactionType)
        
        switch result {
        case .success:
            dismissModal()
            flowDelegate?.didAddTransaction()
        case .failure(let error):
            let message: String
            switch error {
            case AddTransactionModalViewModel.TransactionError.invalidDateFormat:
                message = "alert.error.invalidDateFormat".localized
            case AddTransactionModalViewModel.TransactionError.invalidCategory:
                message = "alert.error.invalidCategory".localized
            case AddTransactionModalViewModel.TransactionError.invalidType:
                message = "alert.error.invalidTransactionType".localized
            default:
                message = "alert.error.defaultMessage".localized
            }
            handleError(title: "alert.error.title".localized, message: message)
        }
    }
    
    func transactionTypeSelectorDidSelect(_ selector: TransactionTypeSelector) {
        if selector.variant == .selected {
            contentView.incomeSelectorButton.variant = .normal
            contentView.expenseSelectorButton.variant = .normal
        } else {
            if selector.transactionType == .income {
                contentView.incomeSelectorButton.variant = .selected
                contentView.expenseSelectorButton.variant = .unselected
            } else {
                contentView.expenseSelectorButton.variant = .selected
                contentView.incomeSelectorButton.variant = .unselected
            }
        }
    }
    
    func closeModal() {
        dismissModal()
    }
}
