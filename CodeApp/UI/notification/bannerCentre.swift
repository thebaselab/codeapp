//
//  bannerCentre.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct Banner: View{
    
    let data: BannerData
    @Binding var isPresented: Bool
    @Binding var isRemoved: Bool
    
    var body: some View {
        VStack{
            HStack{
                data.level.icon
                Text(data.title).lineLimit(5).font(.system(size: 14)).foregroundColor(Color.init("T1"))
                Spacer()
            }.frame(minHeight: 50).padding(.horizontal, 10)
        }.frame(maxWidth: 300).background(Color.init(id: "sideBar.background")).cornerRadius(10).onTapGesture{
            withAnimation{
                isRemoved = true
            }
        }
        .onAppear{
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                withAnimation{
                    isPresented = false
                }
            }
        }
    }
}

struct BannerWtihProgress: View {
    
    let data: BannerData
    @Binding var isPresented: Bool
    @Binding var isRemoved: Bool
    
    var body: some View {
        VStack{
            HStack{
                data.level.icon
                Text(data.title).lineLimit(1).font(.system(size: 14)).foregroundColor(Color.init("T1"))
                Spacer()
            }.frame(height: 50).padding(.leading, 10).padding(.trailing, 10)
            
            ProgressView(data.progress!).padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10)).onChange(of: data.progress, perform: { value in
                if data.progress!.isFinished{
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation{
                            isRemoved = true
                        }
                    }
                }
            })
            .progressViewStyle(LinearProgressViewStyle())
            
        }.frame(maxWidth: 300).background(Color.init(id: "sideBar.background")).cornerRadius(10).onTapGesture{
            withAnimation{
                isRemoved = true
            }
        }
    }
}

struct BannerWithButton: View {
    
    let data: BannerData
    @Binding var isPresented: Bool
    @Binding var isRemoved: Bool
    @AppStorage("accentColor") var accentColor: String = "blue"
    
    var body: some View {
        VStack{
            HStack{
                data.level.icon
                Text(data.title).lineLimit(2).font(.system(size: 14)).foregroundColor(Color.init("T1"))
                Spacer()
                Image(systemName: "xmark").font(.system(size: 12)).foregroundColor(Color.init("T1")).onTapGesture{isRemoved = true}
            }.frame(height: 50).padding(.leading, 10).padding(.trailing, 10)
            
            HStack{
                Text("Source: \(data.source ?? "")").lineLimit(2).font(.system(size: 12)).foregroundColor(Color.gray)
                Spacer()
                if data.primaryAction != nil{
                    Text(data.primaryTitle).foregroundColor(.white).lineLimit(1).font(.system(size: 12)).padding(.leading, 8).padding(.trailing, 8).padding(.top, 4).padding(.bottom, 4).background(Color.init(accentColor)).cornerRadius(10).onTapGesture {
                        data.primaryAction?()
                        withAnimation{
                            isRemoved = true
                        }
                    }
                }
                if data.secondaryAction != nil{
                    Text(data.secondaryTitle).foregroundColor(.white).lineLimit(1).font(.system(size: 12)).padding(.leading, 8).padding(.trailing, 8).padding(.top, 4).padding(.bottom, 4).background(Color.init(accentColor)).cornerRadius(10).onTapGesture {
                        data.secondaryAction?()
                        withAnimation{
                            isRemoved = true
                        }
                    }
                }
                
            }.frame(height: 30).padding(.leading, 10).padding(.trailing, 10).padding(.bottom, 10)
            
        }.frame(maxWidth: 300).background(Color.init(id: "sideBar.background")).cornerRadius(10)
    }
}

struct BannerCentreView: View{
    
    @EnvironmentObject var App: MainApp
    
    var body: some View {
        VStack(spacing: 10){
            ForEach(App.notificationManager.banners.indices, id: \.self){i in
                if !App.notificationManager.banners[i].isRemoved && (App.notificationManager.banners[i].isPresented || App.notificationManager.isShowingAllBanners){
                    App.notificationManager.banners[i].data.makeBanner(isPresented: $App.notificationManager.banners[i].isPresented, isRemoved: $App.notificationManager.banners[i].isRemoved).animation(.spring())
                }
            }
        }
    }
}
