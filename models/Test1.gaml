/**
* Name: Test1
* Based on the internal empty template. 
* Author: Hoang The
* Tags: 
*/
model Test1

/* Insert your model definition here */
global {
	bool display3D <- false;

	//Check if we use simple data or more complex roads
	file shape_file_roads <- file("../includes/bbbike/roadsTS.shp");
	file shape_file_nodes <- file("../includes/bbbike/nodeTS.shp");
	geometry shape <- envelope(shape_file_roads);
	graph road_network;
	int nb_people <- 200;
	point startTS <-(426.19927829899825,13.154359925538301) ;

	init {
	//create the intersection and check if there are traffic lights or not by looking the values inside the type column of the shapefile and linking
	// this column to the attribute is_traffic_signal.
		create intersection from: shape_file_nodes with: [is_traffic_signal::(read("type") = "traffic_lights")];

		//create road agents using the shapefile and using the oneway column to check the orientation of the roads if there are directed
		create road from: shape_file_roads with: [lanes::int(read("lanes")), oneway::string(read("oneway"))] {
			geom_display <- shape + (2.5 * lanes);
			maxspeed <- (lanes = 1 ? 30.0 : (lanes = 2 ? 50.0 : 70.0)) °km / °h;
			switch oneway {
				match "no" {
					create road {
						lanes <- max([1, int(myself.lanes / 2.0)]);
						shape <- polyline(reverse(myself.shape.points));
						maxspeed <- myself.maxspeed;
						geom_display <- myself.geom_display;
						linked_road <- myself;
						myself.linked_road <- self;
					}

					lanes <- int(lanes / 2.0 + 0.5);
				}

				match "-1" {
					shape <- polyline(reverse(shape.points));
				}

			}

		}

		map general_speed_map <- road as_map (each::(each.shape.perimeter / each.maxspeed));

		//creation of the road network using the road and intersection agents
		road_network <- (as_driving_graph(road, intersection)) with_weights general_speed_map;

		//initialize the traffic light
		ask intersection {
			do initialize;
		}

		create people number: nb_people {
			max_speed <- 160 #km / #h;
			vehicle_length <- 5.0 #m;
			right_side_driving <- true;
			proba_lane_change_up <- 0.1 + (rnd(500) / 500);
			proba_lane_change_down <- 0.5 + (rnd(500) / 500);
			location <- one_of(intersection where empty(each.stop)).location;
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

}

//species that will represent the intersection node, it can be traffic lights or not, using the skill_road_node skill
species intersection skills: [skill_road_node] {
	bool is_traffic_signal;
	list<list> stop;
	int time_to_change <- 100;
	int counter <- rnd(time_to_change);
	list<road> ways1;
	list<road> ways2;
	rgb color_fire;
	int status_traffic_signal <- -1; // 0: green; 1: yellow; 2: red; -1: not traffic signal    
	list<intersection> mutex_node; // list of exclusive nodes, meaning they can not be green at the same time with this node, added by thanhlnt
	bool canGreen;

	action initialize {
		if (is_traffic_signal) {
			status_traffic_signal <- rnd(2) + 1;
			do compute_crossing;
			stop << [];
			if (status_traffic_signal = 0) {
				do to_green;
			} else if (status_traffic_signal = 1) {
				do to_yellow;
			} else {
				do to_red;
			}

		}

	}

	action compute_crossing {
//	   	 write '' + name +  ' - roads_in : ' +length(roads_in);
		if (length(roads_in) >= 2) {
			road rd0 <- road(roads_in[0]);
			list<point> pts <- rd0.shape.points;
			float ref_angle <- float(last(pts) direction_to rd0.location);
			loop rd over: roads_in {
				list<point> pts2 <- road(rd).shape.points;
				float angle_dest <- float(last(pts2) direction_to rd.location);
				float ang <- abs(angle_dest - ref_angle);
				if (ang > 45 and ang < 135) or (ang > 225 and ang < 315) {
					ways2 << road(rd);
				}

			}

		}

		loop rdi over: roads_in {
			if not (rdi in ways2) {
				ways1 << road(rdi);
			}

		}

		// added by thanhlnt
		if (is_traffic_signal) {
			loop rdo over: roads_out {
				loop rdi over: intersection(road(rdo).target_node).roads_in {
					intersection sn <- intersection(road(rdi).source_node);
					if ((sn.name != name) and (sn.is_traffic_signal) and not contains(mutex_node, sn)) {
						mutex_node << sn;
						//   					 write ' ' + name + ' : ' + sn;
					}

				}

			}

		}

	}

	action to_green {
		stop[0] <- ways2;
		color_fire <- #green;
		status_traffic_signal <- 1;
		time_to_change <- 100;
	}

	action to_yellow {
		stop[0] <- ways1;
		color_fire <- #yellow;
		status_traffic_signal <- 2;
		time_to_change <- 20;
	}

	action to_red {
		stop[0] <- ways1;
		color_fire <- #red;
		status_traffic_signal <- 0;
		time_to_change <- 100;
	}

	reflex dynamic_node when: is_traffic_signal {
		counter <- counter + 1;
		if (counter >= time_to_change) {
			counter <- 0;
			if (status_traffic_signal = 0) {
			// check if it can become to green or have to wait ?
				canGreen <- true;
				loop mtn over: mutex_node {
					if (intersection(mtn).color_fire = #green) {
						canGreen <- false;
						//   					 write ' ' + name + '->' + status_traffic_signal + ' : ' + mtn + '->' + intersection(mtn).status_traffic_signal;
					}

				}

				if (canGreen) {
					do to_green;
				} else {
					counter <- rnd(int(time_to_change / 2));
				}

			} else if (status_traffic_signal = 1) {
				do to_yellow;
			} else {
				do to_red;
			}

		}

	}

	aspect default {
		if (display3D) {
			if (is_traffic_signal) {
				draw box(1, 1, 10) color: #black;
				draw sphere(3) at: {location.x, location.y, 10} color: color_fire;
			}

		} else {
			if (is_traffic_signal) {
				draw circle(5) color: color_fire;
			} else {
				draw circle(0.5) color: #blue;
			}

		}

	}

}

//species that will represent the roads, it can be directed or not and uses the skill skill_road
species road skills: [skill_road] {
	geometry geom_display;
	string oneway;
	int lanes;

	aspect default {
		if (display3D) {
			draw geom_display color: #lightgray;
		} else {
			draw shape color: #white end_arrow: 3;
		}

	}

}

//People species that will move on the graph of roads to a target and using the driving skill
species people skills: [advanced_driving] {
	rgb color <- #blue; //rnd_color(255);
	int counter_stucked <- 0;
	int threshold_stucked;
	bool breakdown <- false;
	float proba_breakdown;
	intersection target;

	reflex breakdown when: flip(proba_breakdown) {
		breakdown <- true;
		max_speed <- 1 #km / #h;
	}

	reflex time_to_go when: final_target = nil {
		target <- one_of(intersection);
		current_path <- compute_path(graph: road_network, target: target);
		if (current_path = nil) {
			location <- one_of(intersection).location;
		} }

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
			draw rectangle(1, vehicle_length) + triangle(1) rotate: heading + 90 depth: 1 color: color at: loc;
			if (breakdown) {
				draw circle(1) at: loc color: #red;
			}

		} else {
			draw breakdown ? rectangle(5, 3) : triangle(5) color: color rotate: heading + 90;
		}

	}

	point calcul_loc {
		if (current_road = nil) {
			return location;
		} else {
			float val <- (road(current_road).lanes - current_lane) + 0.5;
			val <- on_linked_road ? -val : val;
			if (val = 0) {
				return location;
			} else {
				return (location + {cos(heading + 90) * val, sin(heading + 90) * val});
			}

		}

	} }

experiment HanoiCity type: gui {
	parameter "if true, 3D display, if false 2D display:" var: display3D category: "GIS";
	output {
		display Main type: opengl synchronized: true background: #gray {
			species road;
			species intersection;
			species people;
		}

	}

}
