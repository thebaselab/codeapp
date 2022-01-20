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

export const enum FindOption {
	None = 0,
	/**
	 * equivalent of ONIG_OPTION_NOT_BEGIN_STRING: (str) isn't considered as begin of string (* fail \A)
	 */
	NotBeginString = 1,
	/**
	 * equivalent of ONIG_OPTION_NOT_END_STRING: (end) isn't considered as end of string (* fail \z, \Z)
	 */
	NotEndString = 2,
	/**
	 * equivalent of ONIG_OPTION_NOT_BEGIN_POSITION: (start) isn't considered as start position of search (* fail \G)
	 */
	NotBeginPosition = 4,
	/**
	 * used for debugging purposes.
	 */
	DebugCall = 8,
}

export class OnigScanner {
	constructor(patterns: string[]);
	public dispose(): void;
	public findNextMatchSync(string: string | OnigString, startPosition: number, options: number): IOnigMatch | null;
	public findNextMatchSync(string: string | OnigString, startPosition: number, debugCall: boolean): IOnigMatch | null;
	public findNextMatchSync(string: string | OnigString, startPosition: number): IOnigMatch | null;
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
