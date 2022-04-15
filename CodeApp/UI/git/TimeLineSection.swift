//
//  TimeLineSection.swift
//  Code
//
//  Created by Ken Chung on 12/4/2022.
//

import Foundation

//                Section(header:
//                            Text(NSLocalizedString("Timeline", comment: ""))
//                            .foregroundColor(Color.init("BW"))
//                ){
//                    if App.commits.isEmpty{
//                        Text("The Git repository is empty.").foregroundColor(.gray).font(.system(size: 12, weight: .light))
//                    }
//                    ForEach(App.commits.indices.reversed(), id: \.self){index in
//                        HStack{
//                            ZStack{
//                                if index != 0{
//                                    Rectangle().fill(Color.gray).frame(maxWidth: 1, maxHeight: .infinity)
//                                }
//                                VStack{
//                                    ZStack{
//                                        Circle().fill(Color.white).frame(width: 8, height: 8)
//                                        Circle().stroke(Color.gray, lineWidth: 1).frame(width: 8, height: 8)
//                                    }.padding(.top, 3)
//                                    Spacer()
//                                }
//                            }
//                            VStack(alignment: .leading){
//                                Text("\(App.commits[index].author.date)").font(.system(size: 12)).foregroundColor(.gray).padding(.bottom, 3)
//                                Text("\(App.commits[index].message)").font(.system(size: 12)).fontWeight(.semibold).foregroundColor(Color.init("T1"))
//                                Text("\(App.commits[index].author.name)").font(.system(size: 12)).foregroundColor(.gray).padding(.bottom, 30)
//
//                            }
//                            Spacer()
//                        }.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
//                    }
//                }
