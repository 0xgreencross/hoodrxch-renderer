// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Mask} from "./Mask.sol";
import {Rng} from "./Rng.sol";

/// Shared internal types for the renderer pipeline.
library T {
    string internal constant BLACK = "#000000";
    string internal constant ACID = "#CCFF00";
    string internal constant RED = "#FF2A2A";
    string internal constant PINK = "#FF3EB5";
    string internal constant WHITE = "#FFFFFF";

    struct Slc {
        int256 y;
        int256 h;
        int256 dx;
        bool smear;
    }

    struct Gen {
        string figure;
        Mask.Traits t;
        Slc[] slices;
        Rng.R rng;
        int256[3][2] eyeScreen; // [x, y, r] per eye, unit coords
    }
}
