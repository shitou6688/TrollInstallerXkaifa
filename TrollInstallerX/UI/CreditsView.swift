//
//  CreditsView.swift
//  TrollInstallerX
//
//  Created by Alfie on 26/03/2024.
//

import SwiftUI

struct Credit {
    var name: String
    var link: URL
}

let credits: [Credit] = [
    Credit(name: "opa334", link: URL(string: "https://x.com/opa334dev")!),
    Credit(name: "Kaspersky", link: URL(string: "https://securelist.com/operation-triangulation-the-last-hardware-mystery/111669/")!),
    Credit(name: "wh1te4ever", link: URL(string: "https://github.com/wh1te4ever")!),
    Credit(name: "xina520", link: URL(string: "https://x.com/xina520")!),
    Credit(name: "staturnz", link: URL(string: "https://github.com/staturnzz")!),
    Credit(name: "DTCalabro", link: URL(string: "https://github.com/DTCalabro")!),
    
    Credit(name: "felib-pb", link: URL(string: "https://github.com/felix-pb")!),
    Credit(name: "kok3shidoll", link: URL(string: "https://github.com/kok3shidoll")!),
    Credit(name: "Zhuowei", link: URL(string: "https://github.com/zhuowei")!),
    Credit(name: "dhinakg", link: URL(string: "https://github.com/dhinakg")!),
    Credit(name: "aaronp613", link: URL(string: "https://x.com/aaronp613")!),
    Credit(name: "JJTech", link: URL(string: "https://github.com/JJTech0130")!)
]

struct CreditsView: View {
    var body: some View {
        
        VStack(spacing: 20) {
            Text("鸣谢")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 8)
            
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 4) {
                    ForEach(0..<(credits.count / 2)) { index in
                        CreditRow(credit: credits[index])
                    }
                }
                
                VStack(spacing: 4) {
                    ForEach((credits.count / 2)..<credits.count) { index in
                        CreditRow(credit: credits[index])
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
    }
}

struct CreditRow: View {
    let credit: Credit
    
    var body: some View {
        Link(destination: credit.link) {
            HStack(spacing: 8) {
                Text(credit.name)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }
}


struct CreditsView_Previews: PreviewProvider {
    static var previews: some View {
        CreditsView()
    }
}
