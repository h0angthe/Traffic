/**
* Name: RoadTraffic
* Based on the internal empty template. 
* Author: Hoang The
* Tags: 
*/


model RoadTraffic

/* Insert your model definition here */
global {
	file shapefile_roads <- file("../includes/bbbike/roadsTS.shp");
	file shapefile_buildings <- file("../includes/bbbike/buildingsTS1.shp");
	geometry shape <- envelope(shapefile_buildings);
	
	
	bool building_display <- true;
	bool display3D <- false;
	bool road_display <- true;
	bool showAgent <- true;
	bool dynamic_background <- false;
	float current_hour <- 6.0;
	graph road_network;
	int nb_people <- 200;
	point start1 <- {156.57607030107175,587.3316504620947};
	float lane_width <- 0.7;  
		
	graph the_graph;
	
	init{
		create Buildings from: shapefile_buildings with:[type::string(get("type")),height::float(get ("Z"))]{
			if type="commerce" or type="apartments"{
				color <- #goldenrod;
			}if type="university" {
				color <- #yellow;
			}if type="habitat"{
				color <- #white;
			}

		}
		create roads from: shapefile_roads with: [lanes::int(read("lanes")), oneway::string(read("oneway"))] {
			geom_display <- shape + (5.5 * lanes);
			maxspeed <- (lanes = 1 ? 30.0 : (lanes = 6 ? 50.0 : 60.0)) °km / °h;
			switch oneway {
				match "yes" {
					create roads {
						lanes <- myself.lanes;
						shape <- polyline(reverse(myself.shape.points));
						maxspeed <- myself.maxspeed;
						geom_display <- myself.geom_display;
						linked_road <- myself;
						myself.linked_road <- self;
					}

					lanes <- int(lanes / 5.0 + 0.5);
				}

				match "no" {
					shape <- polyline(reverse(shape.points));
				}

			}

		}
		map general_speed_map <- roads as_map (each::(each.shape.perimeter / each.maxspeed));

		//creation of the road network using the road and intersection agents
		road_network <- as_edge_graph(roads) with_weights general_speed_map;
		
			create people number: nb_people {
			max_speed <- 160 #km / #h;
			vehicle_length <- 5.0 #m;
			right_side_driving <- true;
			proba_lane_change_up <- 0.1 + (rnd(500) / 500);
			proba_lane_change_down <- 0.5 + (rnd(500) / 500);
			location <- one_of(start1).location;
			security_distance_coeff <- 5 / 9 * 3.6 * (1.5 - rnd(1000) / 1000);
			proba_respect_priorities <- 1.0 - rnd(200 / 1000);
			proba_respect_stops <- [1.0];
			proba_block_node <- 0.0;
			proba_use_linked_road <- 0.0;
			max_acceleration <- 5 / 3.6;
			speed_coeff <- 1.2 - (rnd(400) / 1000);
			threshold_stucked <- int((1 + rnd(5)) #mn);
			proba_breakdown <- 0.00001;
		}
	}
	species Buildings {
	string type;
	float height;
	//string usage;
	//string scale;
	rgb color <- #black;

	aspect base {
		if (building_display) {
			draw shape color: color;
		}

	}

	aspect base3D {
		if (display3D) {
			draw shape color: color depth: height;
		}

	}
}
species roads skills: [skill_road] {
	geometry geom_display;
	string oneway;
	int lanes;

	aspect default {
		if (display3D) {
			draw geom_display color: #lightgray;
		} else {
			draw shape color: #white ;
		}
		
	}

}
species people skills: [advanced_driving] {
		rgb color <- #yellow; //rnd_color(255);
	int counter_stucked <- 0;
	int threshold_stucked;
	bool breakdown <- false;
	float proba_breakdown;
	point target;
//	intersection target;

	reflex breakdown when: flip(proba_breakdown) {
		breakdown <- true;
		max_speed <- 1 #km / #h;
	}

	reflex time_to_go when: final_target = nil {
		target <- one_of(start1);
//		current_path <- compute_path(graph: road_network, target: target);
		if (current_path = nil) {
			location <- one_of(start1).location;
		} 
	}

	reflex move when: current_path != nil and final_target != nil {
		do drive;
		if (final_target != nil) {
			if real_speed < 5 #km / #h {
				counter_stucked <- counter_stucked + 1;
				if (counter_stucked mod threshold_stucked = 0) {
					proba_use_linked_road <- min([1.0, proba_use_linked_road + 0.1]);
				}
	
			} else {
				counter_stucked <- 0;
				proba_use_linked_road <- 0.0;
			}
		}
	}
	aspect default {
		if (display3D) {
			point loc <- calcul_loc();
			draw rectangle(1,vehicle_length) + triangle(1) rotate: heading + 90 depth: 1 color: color at: loc;
			if (breakdown) {
				draw circle(1) at: loc color: #red;
			}
		}else {
			draw breakdown ? square(8) : triangle(8) color: color rotate: heading + 90;
		}
		
	}
	point calcul_loc {
		if (current_road = nil) {
			return location;
		} else {
			float val <- (roads(current_road).lanes - current_lane) + 0.5;
			val <- on_linked_road ? -val : val;
			if (val = 0) {
				return location;
			} else {
				return (location + {cos(heading + 90) * val, sin(heading + 90) * val});
			}

		}

	}
}
}
experiment main type: gui {
//	float minimum_cycle_duration <- 0.02;
	output {
		
		display map type:opegl
		background: dynamic_background?
		rgb(sin_rad(#pi * current_hour / 24.0) * 160, sin_rad(#pi * current_hour / 24.0) * 110, sin_rad(#pi * current_hour / 24.0) * 80) 
		:#black 
		{
			species Buildings aspect: base;
			species roads;
			species people;
		}
		}
		}
