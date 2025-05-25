// Configurable parameters.
front_plate_width = 200;
front_plate_height = 95;
front_plate_depth = 2;

// Size of the PCB.
pcb_width = 194.945;
pcb_height = 90.170;

// Derived variables.
offset_x = (front_plate_width - pcb_width) / 2;
offset_y = (front_plate_height - pcb_height) / 2;

// Set the fidelity of round holes.
$fn = 50;

// Show the PCB.
//module PCB()
//{
//    color("green") {
//        translate([offset_x, pcb_height + offset_y, -5]) {
//            import("Generic_Front_Panel_PCB.stl");
//        }
//    }
//}
//PCB();

// Create the front plate.
module FrontPlate() {
    cube([front_plate_width, front_plate_height, front_plate_depth]);
}

// Cylinder to cut out the hole for the power LED.
module LedHole() {
    cylinder(h = front_plate_depth * 4, r = 3, center = true);
}

// Prism to cut out the hole for the LED segment displays.
module SegmentsHole() {
    translate([6.5, 62.5, 0]) {
        cube([71, 22, front_plate_depth * 2]);
    }
}

// Prism to cut out a hole for a push button.
module PushButton() {
    cube([13.5, 13.0, front_plate_depth * 4], center=true);
}

// Cut a row of four push button holes.
hole_sep_x = 49.0 / 3;
hole_sep_y = 60.5 / 4;
module PushButtonRow() {
    PushButton();
    translate([hole_sep_x, 0, 0]) {
        PushButton();
    }
    translate([hole_sep_x * 2, 0, 0]) {
        PushButton();
    }
    translate([hole_sep_x * 3, 0, 0]) {
        PushButton();
    }
}

// Cut five rows of push button holes.
module PushButtonGrid() {
    PushButtonRow();
    translate([0, -hole_sep_y, 0]) {
        PushButtonRow();
    }
    translate([0, -hole_sep_y * 2, 0]) {
        PushButtonRow();
    }
    translate([0, -hole_sep_y * 3, 0]) {
        PushButtonRow();
    }
    translate([0, -hole_sep_y * 4, 0]) {
        PushButtonRow();
    }
}

// Cut a hole for a mounting screw.
module MountingHole() {
    cylinder(h = front_plate_depth * 4, r = 1.6, center = true);
}

// Build the entire front plate with holes cut.
difference() {
    FrontPlate();
    translate([offset_x, offset_y, -front_plate_depth/2]) {
        SegmentsHole();
        translate([97.8, 80, -front_plate_depth / 3]) {
            LedHole();
        }
        translate([129.8, 76.2, 0]) {
            PushButtonGrid();
        }
        translate([3.8, 3.8, 0]) {
            MountingHole();
        }
        translate([3.8, 86.4, 0]) {
            MountingHole();
        }
        translate([191, 3.8, 0]) {
            MountingHole();
        }
        translate([191, 86.4, 0]) {
            MountingHole();
        }
        translate([97.8, 45, 0]) {
            MountingHole();
        }
    }
}
