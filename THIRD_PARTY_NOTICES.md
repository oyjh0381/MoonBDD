# Third-Party Notices

MoonBDD source is an original MoonBit implementation. It does not copy or port
source from CUDD, BuDDy, Sylvan, or another BDD library.

Algorithmic background was informed by public ROBDD literature, especially
Randal E. Bryant, “Graph-Based Algorithms for Boolean Function Manipulation,”
IEEE Transactions on Computers 35(8), 1986. Mathematical ideas and bibliographic
facts are not redistributed source code.

The official `moonbitlang/async` package supplies Native CLI I/O under its
published license. Tests use only original hand-written formulas and fixtures.

The Windows argv adapter and its PowerShell launchers in `tools/windows/` were
adapted from the local MoonBitemporal-yt project's Apache-2.0 development tools
(2026-10-30). MoonBDD adjusts the build to support non-ASCII repository paths.
These auxiliary tools normalize extended DOS path arguments before launching
the installed official compiler; they contain no third-party BDD implementation.
