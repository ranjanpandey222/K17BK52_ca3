import SwiftUI

struct LearnListView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(LearnLibrary.all) { article in
                    NavigationLink {
                        LearnArticleView(article: article)
                    } label: {
                        Card {
                            HStack(spacing: 12) {
                                IconBadge(systemImage: article.systemImage)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(article.title).font(.headline).foregroundStyle(Theme.textPrimary)
                                    Text(article.summary).font(.subheadline).foregroundStyle(Theme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Text(LearnLibrary.reviewNote).font(.caption).foregroundStyle(Theme.textSecondary).padding(.top, 8)
            }
            .padding(20)
        }
        .ebbScreen()
        .navigationTitle("Learn")
    }
}

struct LearnArticleView: View {
    let article: LearnArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                IconBadge(systemImage: article.systemImage, size: 52)
                Text(article.title).font(.largeTitle.weight(.bold)).foregroundStyle(Theme.textPrimary)
                ForEach(Array(article.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 8) {
                        if let heading = section.heading {
                            Text(heading).font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        }
                        ForEach(section.paragraphs, id: \.self) { paragraph in
                            Text(paragraph).foregroundStyle(Theme.textPrimary).fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(section.bullets, id: \.self) { bullet in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle().fill(Theme.accent).frame(width: 6, height: 6)
                                Text(bullet).foregroundStyle(Theme.textPrimary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                Text(LearnLibrary.reviewNote)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ebbScreen()
        .navigationBarTitleDisplayMode(.inline)
    }
}
