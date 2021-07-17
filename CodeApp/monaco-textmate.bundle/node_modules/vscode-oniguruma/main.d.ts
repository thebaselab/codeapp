/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/

export interface IOptions {
	data: ArrayBuffer | Response;
	print?(str: string): void;
}

export function loadWASM(options: IOptions): Promise<void>;
export function loadWASM(data: ArrayBuffer | Response): Promise<void>;
export function createOnigString(str: string): OnigString;
export function createOnigScanner(patterns: string[]): OnigScanner;
export function setDefaultDebugCall(defaultDebugCall: boolean): void;

export class OnigString {
	readonly content: string;
	constructor(content: string);
	public dispose(): void;
}

export class OnigScanner {
	constructor(patterns: string[]);
	public dispose(): void;
	public findNextMatchSync(string: string | OnigString, startPosition: number, debugCall?: boolean): IOnigMatch;
}

export interface IOnigCaptureIndex {
	start: number
	end: number
	length: number
}

export interface IOnigMatch {
	index: number
	captureIndices: IOnigCaptureIndex[]
}
