const cimgui = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "1");
    @cDefine("CIMGUI_USE_GLFW", "1");
    @cDefine("CIMGUI_USE_OPENGL3", "1");
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
});

pub usingnamespace cimgui;
