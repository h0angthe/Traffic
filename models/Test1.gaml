/**
* Name: Test1
* Based on the internal empty template. 
* Author: Hoang The
* Tags: 
*/
model Test1

/* Insert your model definition here */
global {
	bool display3D<- false;
	
	//Check if we use simple data or more complex roads
	file shape_file_roads <- file("../includes/bbbike/roadsTS.shp");
	file shape_file_nodes <- file("../includes/bbbike/nodes.shp");
	geometry shape <- envelope(shape_file_nodes) + 50.0;
	graph road_network;
	int num_car <- 500;
	float lane_width <- 2.0;
	float learning_rate <- 0.1;
	float discout_factor <- 0.5;

	init {
	//create the intersection and check if there are traffic lights or not by looking the values inside the type column of the shapefile and linking
	// this column to the attribute is_traffic_signal. 
		create intersection from: shape_file_nodes with: [is_traffic_signal::(read("type") = "traffic_singals")]{
			closest_node <- intersection where (each != self); 
		}

		//create road agents using the shapefile and using the oneway column to check the orientation of the roads if there are directed
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[24],intersection[17]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[17],intersection[2]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[17],intersection[0]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[0],intersection[9]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[0],intersection[27]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[10],intersection[9]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[27],intersection[10]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[2],intersection[18]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[18],intersection[19]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[4],intersection[18]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[11],intersection[4]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[8],intersection[25]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[25],intersection[11]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[11],intersection[10]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[15],intersection[6]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[6],intersection[7]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line(reverse([intersection[29],intersection[7]])));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line(reverse([intersection[7],intersection[29]])));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[14],intersection[16]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[8],intersection[4]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[16],intersection[28]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[16],intersection[6]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[28],intersection[15]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[15],intersection[11]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[7],intersection[8]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[26],intersection[12]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[12],intersection[15]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[10],intersection[12]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[12],intersection[20]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[20],intersection[21]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[23],intersection[26]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[26],intersection[12]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line(reverse([intersection[2],intersection[3]])));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line(reverse([intersection[3],intersection[2]])));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[3],intersection[21]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[13],intersection[3]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[21],intersection[1]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[5],intersection[13]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[13],intersection[14]]));
	create road with:(num_lanes:1, maxspeed: 50#km/#h, shape:line([intersection[9],intersection[22]]));
	
	map<intersection, float> Q_table <- intersection as_map(each::rnd(0.1,100000.0));
	
	road_network <- as_driving_graph(road,intersection);

		//initialize the traffic light
		ask intersection where each.is_traffic_signal {
			do initialize;
		}
	list<intersection> start <- intersection where (each.name="intersection5" or each.name="intersection23" or each.name="intersection29" or each.name="intersection24");
	list<intersection> end <- intersection where (each.name="intersection5" or each.name="intersection19" or each.name="intersection22" or each.name="intersection1");
	
		create car number: num_car with:(target :one_of(end)) {
		vehicle_length <- 3.8 #m;
		//car occupies 2 lanes
		num_lanes_occupied <-1;
		max_speed <-150 #km / #h;
		max_acceleration <- 5 / 3.6;
				
		right_side_driving <- true;
		proba_lane_change_up <- 0.1 + (rnd(500) / 500);
		proba_lane_change_down <- 0.5 + (rnd(500) / 500);		
		proba_block_node <- 0.0;
		proba_respect_priorities <- 1.0 - rnd(200 / 1000);
		proba_respect_stops <- [1.0];
		proba_use_linked_road <- 0.0;
		security_distance_coeff <- 5 / 9 * 3.6 * (1.5 - rnd(1000) / 1000);
		speed_coeff <- 1.2 - (rnd(400) / 1000);
		
//		proba_lane_change_up <-1.0;
		
		lane_change_limit <- 2;
		linked_lane_limit <- 0;
		
		start_car <- one_of(start);
		location<- any_location_in(start_car);
		
		}

	}
	
	
	 reflex find_closest_neighbours {
    	ask intersection {
    		if(closest_node !=[]){
      		list<intersection> closest_neighbour <- closest_node closest_to(self,3);
      		write "Closest neighbour of " + self + " is " + closest_neighbour;
      	}else{
      		write "no "; 
      	}
    }
  }

}

//species that will represent the intersection node, it can be traffic lights or not, using the skill_road_node skill
species intersection skills: [skill_road_node] {
	bool is_traffic_signal;
	float time_to_change <- 60#s ;
	float counter <- rnd(time_to_change);
	
	list<intersection> closest_node <- [];
	
	//take into consideration the roads coming from both direction (for traffic light)
	list<road> ways1;
	list<road> ways2;
	
	//if the traffic light is green
	bool is_green;
	rgb color <- #yellow;

	//initialize the traffic light
	action initialize {
		do compute_crossing;
		stop << [];
		if (flip(0.5)) {
			do to_green;
		} else {
			do to_red;
		}
	}

	action compute_crossing {
		if (length(roads_in) >= 2) {
			road rd0 <- road(roads_in[0]);
			list<intersection> pts <- [intersection[27],intersection[28]];
			float ref_angle <- last(pts) direction_to rd0.location;
			loop rd over: roads_in {
				list<intersection> pts2 <- [intersection[25],intersection[26]];
				float angle_dest <- last(pts2) direction_to rd.location;
				float ang <- abs(angle_dest - ref_angle);
				if (ang > 45 and ang < 135) or (ang > 225 and ang < 315) {
					ways2 << road(rd);
				}
			}
		}

		loop rd over: roads_in {
			if not (rd in ways2) {
				ways1 << road(rd);
			}
		}
	}

	//shift the traffic light to green
	action to_green {
		stop[0] <- ways2;
		color <- #green;
		is_green <- true;
	}

	//shift the traffic light to red
	action to_red {
		stop[0] <- ways1;
		color <- #red;
		is_green <- false;
	}

	//update the state of the traffic light
	reflex dynamic_node when: is_traffic_signal {
		counter <- counter + step;
		if (counter >= time_to_change) {
			counter <- 0.0;
			if is_green {
				do to_red;
			} else {
				do to_green;
			}
		}
	}

	aspect base {
		draw circle(1) color: color;
	}
}

//species that will represent the roads, it can be directed or not and uses the skill skill_road
species road skills: [skill_road] {
	geometry geom_display;

	aspect default {
		if (display3D) {
			draw geom_display color: #lightgray;
		} else {
			draw shape color: #white end_arrow: 5;
		}
		
	}

}

//People species that will move on the graph of roads to a target and using the driving skill
species car skills: [advanced_driving] {
	rgb color <- rnd_color(255); //rnd_color(255);
	intersection start_car <- nil;
	intersection target;
	list<intersection> current_intersection;
	map<intersection, map<intersection, float>> q_table;
	
	reflex time_to_go when: final_target = nil {
//	list<intersection> end <- [ intersection[19], intersection[22],intersection[1]];
	do compute_path graph: road_network target: target;
//	current_intersection <- start_car;
	
	}

	reflex move when: final_target != nil {
//		map<intersection,float> actions <- q_table[current_intersection];
		do drive;
		//if arrived at target, kill it and create a new car
		if (final_target = nil) {
			do unregister;
			do die;
		}
	}

	point compute_position {
		if (current_road != nil) {
			float dist <- (road(current_road).num_lanes - current_lane -
				mean(range(num_lanes_occupied - 1)) - 0.5) * lane_width;
			if violating_oneway {
				dist <- -dist;
			}
		 	point shift_pt <- {cos(heading + 90) * dist, sin(heading + 90) * dist};	
		
			return location + shift_pt;
		} else {
			return {0, 0};
		}
	}
	
	
	aspect default {
		if (current_road != nil) {
			point pos <- compute_position();
				draw rectangle(vehicle_length, lane_width * num_lanes_occupied) 
				at: pos color: color rotate: heading border: #black;
			draw triangle(lane_width * num_lanes_occupied) 
				at: pos color: #white rotate: heading + 90 ;
		}
	}
 }

experiment HanoiCity type: gui {
//	parameter "if true, 3D display, if false 2D display:" var: display3D category: "GIS";
//	
//	action _init_{
//		create simulation with:[
//			shape_file_roads::file("../includes/roads.shp"), 
//			shape_file_nodes::file("../includes/nodes.shp"),
//			nb_people::200
//		];
//	}
	output synchronized: true {
		display city type: 3d background: #gray axes: false{
			species road ;
			species intersection aspect: base;
			species car ;
		}
	}

}

//experiment experiment_ring type: gui {
//	parameter "if true, 3D display, if false 2D display:" var: display3D category: "GIS";
//	
//	action _init_{
//		create simulation with:[
//			shape_file_roads::file("../includes/RoadCircleLanes.shp"), 
//			shape_file_nodes::file("../includes/NodeCircleLanes.shp"),
//			nb_people::20
//		];
//	}
//	output {
//		display carte_principale type: opengl synchronized: true background: #gray{
//			species road ;
//			species intersection ;
//			species people ;
//		}
//
//	}
//
//}

