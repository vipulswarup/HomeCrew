//
//  PDFViewerView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import SwiftUI
import PDFKit

struct PDFViewerView: UIViewRepresentable {
    let url: URL?
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let url = url, let document = PDFDocument(url: url) {
            pdfView.document = document
        }
    }
}

struct PDFViewerContainer: View {
    let url: URL?
    let documentName: String
    
    var body: some View {
        VStack {
            PDFViewerView(url: url)
                .edgesIgnoringSafeArea(.bottom)
                .navigationTitle(documentName)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
