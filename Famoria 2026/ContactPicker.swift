//
//  ContactPicker.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 3/31/26.
//  Copyright © 2026 LS. All rights reserved.
//


import SwiftUI
import ContactsUI

struct ContactPicker: UIViewControllerRepresentable {
    
    var onSelect: (String) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (String) -> Void
        
        init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            if let number = contact.phoneNumbers.first?.value.stringValue {
                onSelect(number)
            }
        }
    }
}


