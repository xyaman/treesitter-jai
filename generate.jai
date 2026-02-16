#import "Basic";
#import "Process";
#import "Compiler";
#import "Bindings_Generator";
#import "File";
#import "File_Utilities";

TS_REPO :: "https://github.com/tree-sitter/tree-sitter";
TS_REPO_PATH :: "tree-sitter";
TS_COMMIT :: "fc5f1b4526ab2ddb4eeee8452443360d4b76a32e"; // version: 0.26.5

recreate_directory :: (path: string) -> bool {
    if file_exists(path) {
        if !delete_directory(path) return false;
    }
    return make_directory_if_it_does_not_exist(path, recursive = true);
}

clone_and_compile_treesitter :: () -> success := false, error := "" {
    if run_command("git", "clone", TS_REPO).exit_code != 0 {
        return error = "Failed to clone treesitter repo.";
    }

    if run_command("git", "checkout", TS_COMMIT, working_directory=TS_REPO_PATH).exit_code != 0 {
        return error = "Failed to checkout to `TS_COMMIT`";
    }

    #if OS == .LINUX && CPU == .X64 {
        if run_command("make", "-C", TS_REPO_PATH).exit_code != 0 {
            return error = "Failed to compile treesitter.";
        }
    }

    #if OS == .WINDOWS && CPU == .X64 {

        BUILD_DIR := tprint("%/build", TS_REPO_PATH);
        make_cmd: [..]string;
        array_add(*make_cmd, "cmake");
        array_add(*make_cmd, "-S");
        array_add(*make_cmd, TS_REPO_PATH);
        array_add(*make_cmd, "-B");
        array_add(*make_cmd, BUILD_DIR);
        array_add(*make_cmd, "-DBUILD_SHARED_LIBS=OFF");
        array_add(*make_cmd, "-DCMAKE_BUILD_TYPE=Release");

        if run_command(..make_cmd).exit_code != 0 {
            return error = "Failed to compile treesitter.";
        }

        make_cmd.count = 0;
        array_add(*make_cmd, "cmake");
        array_add(*make_cmd, "--build");
        array_add(*make_cmd, BUILD_DIR);
        array_add(*make_cmd, "--config");
        array_add(*make_cmd, "Release");

        if run_command(..make_cmd).exit_code != 0 {
            return error = "Failed to compile treesitter.";
        }

        output_dir := "windows/x64";
        recreate_directory(output_dir);
        copy_file(tprint("%/build/Release/tree-sitter.lib", TS_REPO_PATH), tprint("%/tree-sitter_static.lib", output_dir));
    }

    return success = true;
}

#run {
    set_build_options_dc(.{ do_output = false });

    do_clone_and_compile := false;
    do_clean := false;
    {
        w := compiler_create_workspace("generate");
        options := get_build_options(w);
        args := options.compile_time_command_line;
        if array_find(args, "clone") do_clone_and_compile = true;
        if array_find(args, "clean") do_clean = true;
    }

    if do_clone_and_compile {
        delete_directory(TS_REPO_PATH);
        clone_and_compile_treesitter();
    } else if do_clean {
        print("Removing % clone...\n", TS_REPO_PATH);
        delete_directory(TS_REPO_PATH);
        return;
    }

    opts: Generate_Bindings_Options;

    #if OS == .LINUX {
        array_add(*opts.library_search_paths, "linux/x64");
        array_add(*opts.libraries, .{filename = "libtree-sitter", identifier = "libtreesitter"});
    } else #if OS == .WINDOWS {
        array_add(*opts.library_search_paths, "windows/x64");
        array_add(*opts.libraries, .{filename = "tree-sitter_static", identifier = "libtreesitter"});
    }

    opts.generate_library_declarations = true;

    array_add(*opts.include_paths, tprint("%/lib/include/tree_sitter", TS_REPO_PATH));
    array_add(*opts.source_files, "api.h");
    if !generate_bindings(opts, "bindings.jai") {
        compiler_set_workspace_status(.FAILED);
        return;
    }

}
