"""
```julia
UsingsImports()
```

This struct is generated by `compute_usings_imports(ex::Expr)` and
represents the `using` and `import` statements present in the
given expr `ex`. Additionally, the `usings_global` and `imports_global`
represents whether the corresponding `using` or `import` statement
is in global scope or not (nested in a module).
"""
struct UsingsImports
    usings::Vector{Expr}
    usings_global::Vector{Bool}

    imports::Vector{Expr}
    imports_global::Vector{Bool}
end
UsingsImports() = UsingsImports(Expr[], Bool[], Expr[], Bool[])


"""
```julia
compute_usings_imports(ex)::UsingsImports
```

Get the list of subexpressions like `using Module.Z, SomethingElse` or `import Module` that are contained in this expression.
"""
compute_usings_imports(ex) =
    compute_usings_imports!(UsingsImports(), ex)

# Performance analysis: https://gist.github.com/fonsp/280f6e883f419fb3a59231b2b1b95cab
"Preallocated version of [`compute_usings_imports`](@ref)."
function compute_usings_imports!(out::UsingsImports, ex::Any; isglobal=true)
    if isa(ex, Expr)
        if ex.head === :using
            push!(out.usings, ex)
            push!(out.usings_global, isglobal)
        elseif ex.head === :import
            push!(out.imports, ex)
            push!(out.imports_global, isglobal)
        elseif ex.head !== :quote
            ismodule = ex.head === :module
            isglobal &= !ismodule
            for a in ex.args
                compute_usings_imports!(out, a; isglobal)
            end
        end
    end
    out
end

###############

"""
```julia
external_package_names(ex::Union{UsingsImports,Expr})::Set{Symbol}
```

Given `:(using Plots, Something.Else, .LocalModule)`, return `Set([:Plots, :Something])`.
"""
function external_package_names(ex::Expr)::Set{Symbol}
    @assert ex.head == :import || ex.head == :using
    if Meta.isexpr(ex.args[1], :(:))
        external_package_names(Expr(ex.head, ex.args[1].args[1]))
    else
        out = Set{Symbol}()
        for a in ex.args
            if Meta.isexpr(a, :as)
                a = a.args[1]
            end
            if Meta.isexpr(a, :(.))
                if a.args[1] != :(.)
                    push!(out, a.args[1])
                end
            end
        end
        out
    end
end

function external_package_names(x::UsingsImports)::Set{Symbol}
    union!(Set{Symbol}(), Iterators.map(external_package_names, x.usings)...,
                          Iterators.map(external_package_names, x.imports)...)
end
