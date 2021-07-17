
/* These pointers will be stored in the C-object for use in other
    extension modules
*/

// void *PyUFunc_API[] = {
PyUFunc_API[ 0] = (void *) &PyUFunc_Type;
PyUFunc_API[ 1] = (void *) PyUFunc_FromFuncAndData;
PyUFunc_API[ 2] = (void *) PyUFunc_RegisterLoopForType;
PyUFunc_API[ 3] = (void *) PyUFunc_GenericFunction;
PyUFunc_API[ 4] = (void *) PyUFunc_f_f_As_d_d;
PyUFunc_API[ 5] = (void *) PyUFunc_d_d;
PyUFunc_API[ 6] = (void *) PyUFunc_f_f;
PyUFunc_API[ 7] = (void *) PyUFunc_g_g;
PyUFunc_API[ 8] = (void *) PyUFunc_F_F_As_D_D;
PyUFunc_API[ 9] = (void *) PyUFunc_F_F;
PyUFunc_API[10] = (void *) PyUFunc_D_D;
PyUFunc_API[11] = (void *) PyUFunc_G_G;
PyUFunc_API[12] = (void *) PyUFunc_O_O;
PyUFunc_API[13] = (void *) PyUFunc_ff_f_As_dd_d;
PyUFunc_API[14] = (void *) PyUFunc_ff_f;
PyUFunc_API[15] = (void *) PyUFunc_dd_d;
PyUFunc_API[16] = (void *) PyUFunc_gg_g;
PyUFunc_API[17] = (void *) PyUFunc_FF_F_As_DD_D;
PyUFunc_API[18] = (void *) PyUFunc_DD_D;
PyUFunc_API[19] = (void *) PyUFunc_FF_F;
PyUFunc_API[20] = (void *) PyUFunc_GG_G;
PyUFunc_API[21] = (void *) PyUFunc_OO_O;
PyUFunc_API[22] = (void *) PyUFunc_O_O_method;
PyUFunc_API[23] = (void *) PyUFunc_OO_O_method;
PyUFunc_API[24] = (void *) PyUFunc_On_Om;
PyUFunc_API[25] = (void *) PyUFunc_GetPyValues;
PyUFunc_API[26] = (void *) PyUFunc_checkfperr;
PyUFunc_API[27] = (void *) PyUFunc_clearfperr;
PyUFunc_API[28] = (void *) PyUFunc_getfperr;
PyUFunc_API[29] = (void *) PyUFunc_handlefperr;
PyUFunc_API[30] = (void *) PyUFunc_ReplaceLoopBySignature;
PyUFunc_API[31] = (void *) PyUFunc_FromFuncAndDataAndSignature;
PyUFunc_API[32] = (void *) PyUFunc_SetUsesArraysAsData;
PyUFunc_API[33] = (void *) PyUFunc_e_e;
PyUFunc_API[34] = (void *) PyUFunc_e_e_As_f_f;
PyUFunc_API[35] = (void *) PyUFunc_e_e_As_d_d;
PyUFunc_API[36] = (void *) PyUFunc_ee_e;
PyUFunc_API[37] = (void *) PyUFunc_ee_e_As_ff_f;
PyUFunc_API[38] = (void *) PyUFunc_ee_e_As_dd_d;
PyUFunc_API[39] = (void *) PyUFunc_DefaultTypeResolver;
PyUFunc_API[40] = (void *) PyUFunc_ValidateCasting;
PyUFunc_API[41] = (void *) PyUFunc_RegisterLoopForDescr;
PyUFunc_API[42] = (void *) PyUFunc_FromFuncAndDataAndSignatureAndIdentity;
// };
