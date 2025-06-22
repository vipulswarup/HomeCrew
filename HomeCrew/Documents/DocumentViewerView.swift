//
//  DocumentViewerView.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 16/03/25.
//


import SwiftUI
import PDFKit
import QuickLook

struct DocumentViewerView: View {
    let document: StaffDocument
    
    @State private var showingQuickLook = false
    @State private var isImageLoaded = false
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if document.isImage {
                ImageViewer(document: document, image: $image, isLoaded: $isImageLoaded)
            } else if document.isPDF, let fileURL = document.fileURL {
                PDFKitView(url: fileURL)
                    .navigationTitle(document.name)
            } else {
                // For other document types, use QuickLook
                GenericDocumentViewer(document: document, showingQuickLook: $showingQuickLook)
            }
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareButton(document: document)
            }
        }
        .onAppear {
            if document.isImage {
                loadImage()
            }
        }
    }
    
    private func loadImage() {
        guard let fileURL = document.fileURL else { return }
        
        // Try to load from cache first
        if let cachedImage = ImageCache.shared.get(forKey: document.id.recordName) {
            self.image = cachedImage
            self.isImageLoaded = true
            return
        }
        
        // Load from file
        DispatchQueue.global(qos: .userInitiated).async {
            if let loadedImage = UIImage(contentsOfFile: fileURL.path) {
                DispatchQueue.main.async {
                    self.image = loadedImage
                    self.isImageLoaded = true
                    // Cache the image
                    ImageCache.shared.set(loadedImage, forKey: self.document.id.recordName)
                }
            } else if let asset = self.document.asset,
                      let assetURL = asset.fileURL,
                      let loadedImage = UIImage(contentsOfFile: assetURL.path) {
                DispatchQueue.main.async {
                    self.image = loadedImage
                    self.isImageLoaded = true
                    // Cache the image
                    ImageCache.shared.set(loadedImage, forKey: self.document.id.recordName)
                }
            }
        }
    }
}

// MARK: - Image Viewer

struct ImageViewer: View {
    let document: StaffDocument
    @Binding var image: UIImage?
    @Binding var isLoaded: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                if isLoaded, let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale *= delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                scale = scale == 1.0 ? 2.0 : 1.0
                                if scale == 1.0 {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                } else {
                    ProgressView()
                }
            }
        }
    }
}

// MARK: - PDF Viewer

struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true)
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Generic Document Viewer

struct GenericDocumentViewer: View {
    let document: StaffDocument
    @Binding var showingQuickLook: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: document.iconName)
                    .font(.system(size: 72))
                    .foregroundColor(Color(document.iconColor))
                
                Text(document.name)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                
                Text("Tap to preview document")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Preview Document") {
                    showingQuickLook = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 20)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingQuickLook) {
            if let fileURL = document.fileURL {
                QuickLookPreview(url: fileURL)
            }
        }
    }
}

// MARK: - QuickLook Preview

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        
        return UINavigationController(rootViewController: controller)
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreview
        
        init(_ parent: QuickLookPreview) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as NSURL
        }
    }
}

// MARK: - Share Button

struct ShareButton: View {
    let document: StaffDocument
    
    @State private var showingShareSheet = false
    
    var body: some View {
        Button(action: {
            showingShareSheet = true
        }) {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(document.fileURL == nil)
        .sheet(isPresented: $showingShareSheet) {
            if let fileURL = document.fileURL {
                ShareSheet(items: [fileURL])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
