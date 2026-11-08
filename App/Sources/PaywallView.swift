import StoreKit
import SwiftUI

/// Pro の画面。3 回目の小掃除のあと（価値を感じた直後）に 1 度だけ出し、ほかは鍵の行から開く
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var message: String?

    private var product: Product? { model.purchases.products.first { $0.id == AppModel.proID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    ZStack(alignment: .topLeading) {
                        Text("Pro")
                            .font(.system(size: 13, weight: .medium))
                            .kerning(0.6)
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 14).padding(.vertical, 4)
                            .background(TapeShape().fill(Palette.tape.opacity(0.85)))
                            .rotationEffect(.degrees(-4))
                    }
                    Text("家じゅうを、\n替えどきと季節まで")
                        .font(Typo.title(.title))
                        .foregroundStyle(Palette.ink)
                        .kerning(-0.5)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("掃除だけでなく、消耗品の替え時と、その季節だけの手入れも札に出ます。1 度買えば、ずっと使えます。")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: Space.m) {
                        feature(title: "替えどき 22 か所", text: "スポンジ・歯ブラシ・浄水器・換気扇フィルター・消火器の期限など。替えた日が残ります。", sample: "浄水器のカートリッジ・3 か月ごと")
                        feature(title: "季節の手入れ 20 か所", text: "衣替え・扇風機をしまう・加湿器を出す・梅雨の前のカビ予防・台風の前のベランダ。その月にだけ出ます。", sample: "秋の衣替え・10〜11 月")
                        feature(title: "年末の逆算", text: "年末の所が 12 月 28 日までに何か所残り、1 日いくつで間に合うかを出し、札を年末の所から並べます。", sample: "1 日 2 か所ずつで間に合います")
                        feature(title: "1 日 2〜3 か所・自分の場所", text: "追い込みたい日は札を増やせます。金魚の水槽のような、家だけの場所も足せます。", sample: "金魚の水槽・2 週間ごと")
                    }

                    VStack(spacing: Space.s) {
                        switch model.purchases.loadState {
                        case .ready:
                            if let product {
                                Button {
                                    Task { await buy(product) }
                                } label: {
                                    if busy { ProgressView().tint(.white) } else { Text("\(product.displayPrice) で Pro にする（買い切り）") }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(busy || model.isPro)
                                Text("ファミリー共有で、家族も使えます。")
                                    .font(.caption).foregroundStyle(Palette.sub)
                            }
                        case .loading, .idle:
                            ProgressView("読み込んでいます").frame(maxWidth: .infinity, minHeight: 52)
                        case .unavailable:
                            VStack(alignment: .leading, spacing: 6) {
                                Text("いまは購入できません").font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                                Text("通信のよい所で開き直すか、時間をおいてください。無料のままでも、115 か所の小掃除はすべて使えます。")
                                    .font(.footnote).foregroundStyle(Palette.sub)
                                Button("もう一度読み込む") { Task { await model.purchases.load() } }
                                    .buttonStyle(QuietButtonStyle())
                            }
                        }
                        if model.isPro {
                            Label("Pro を使っています", systemImage: "checkmark.seal").foregroundStyle(Palette.mintDeep)
                        }
                        if let message {
                            Text(message).font(.footnote).foregroundStyle(Palette.mintDeep)
                        }
                        Button("購入を復元") {
                            Task {
                                await model.purchases.restore()
                                message = model.isPro ? "Pro を復元しました。" : "復元できる購入が見つかりませんでした。"
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(Palette.sub)
                        .frame(minHeight: 44)
                    }
                    Text("無料のままでも、家じゅうの小掃除 115 か所・間取り図・暦・お知らせは、ずっと使えます。")
                        .font(.footnote).foregroundStyle(Palette.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.xl)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.ground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { if model.purchases.loadState == .idle { await model.purchases.load() } }
            .sensoryFeedback(.success, trigger: model.isPro) { _, new in new && model.hapticsOn }
        }
    }

    private func feature(title: String, text: String, sample: String) -> some View {
        PaperPanel {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(Typo.title(.headline)).foregroundStyle(Palette.ink)
                Text(text).font(.footnote).foregroundStyle(Palette.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                Text(sample)
                    .font(.caption)
                    .foregroundStyle(Palette.mintDeep)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Palette.mintSoft))
            }
        }
    }

    private func buy(_ product: Product) async {
        busy = true
        defer { busy = false }
        switch await model.purchases.purchase(product) {
        case .purchased:
            message = "ありがとうございます。Pro の場所が札に加わりました。"
            model.refreshPlan()
        case .pending:
            message = "承認を待っています。承認されると Pro になります。"
        case .cancelled:
            break
        case .failed:
            message = "購入できませんでした。時間をおいて、もう一度お試しください。"
        }
    }
}
