const webpack = require('webpack');
const path = require("path");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const TerserPlugin = require('terser-webpack-plugin');
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin');

module.exports = {
    entry: __dirname + "/src/js/index.js",
    output: {
        path: __dirname + '/../Sources/MarkdownView/Resources',
        filename: 'main.js'
    },
    module: {
        rules: [
            {
                test: /\.js$/,
                loader: "babel-loader"
            }, {
                test: /\.css$/,
                use: [MiniCssExtractPlugin.loader, 'css-loader']
            }, {
                test: /\.(png|jpe?g|gif|svg|eot|ttf|woff|woff2)$/,
                loader: "file-loader",
                options: {
                    name: "[name].[ext]"
                }
            }
        ]
    },
    plugins: [
        new MiniCssExtractPlugin({
            filename: "[name].css"
        }),
        new webpack.LoaderOptionsPlugin({minimize: true})
    ],
    optimization: {
        minimize: true,
        minimizer: [
            new TerserPlugin({
                extractComments: 'all',
                terserOptions: {
                    compress: true,
                    output: {
                      comments: false,
                      beautify: false
                    }
                }
            }),
            new CssMinimizerPlugin({
                minimizerOptions: {
                  preset: [
                    'default',
                    {
                      discardComments: { removeAll: true },
                    },
                  ],
                },
              }),
        ],
    }
}
