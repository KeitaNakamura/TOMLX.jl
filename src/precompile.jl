using SnoopPrecompile

@precompile_all_calls begin
    TOMLX.parse(@__MODULE__,
                """
                func = @jl x->x
                nums = [@jl(π), 3.14]
                """)
end
