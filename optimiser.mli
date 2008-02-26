val optimising : bool Settings.setting
val inline : Syntax.program -> Syntax.program
val uniquify_names : Syntax.RewriteSyntax.rewriter
val optimise_program : Types.typing_environment
                       * Syntax.program -> Syntax.program

val lift_lets : Syntax.RewriteSyntax.rewriter
val unused_variables : Syntax.RewriteSyntax.rewriter
val renaming : Syntax.RewriteSyntax.rewriter
