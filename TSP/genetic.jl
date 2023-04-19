import Random
using StatsBase
using DataFrames
using Pkg
using XLSX
using CSV


EXCEL_F_NAME_1 = "TSP_29.xlsx"          # 29 cities    
EXCEL_F_NAME_2 = "Dane_TSP_48.xlsx"     # 48 cities
EXCEL_F_NAME_3 = "Dane_TSP_76.xlsx"     # 76 cities
EXCEL_F_NAME_4 = "Dane_TSP_127.xlsx"    # 127 cities

FILES = [EXCEL_F_NAME_1,EXCEL_F_NAME_2,EXCEL_F_NAME_3,EXCEL_F_NAME_4]


function get_distance(city1,city2,distance_matrix)
    return distance_matrix[city1,city2]
end

function get_route_distance(route,distance_matrix)
    distance = 0
    for city in 1:length(route)-1
        distance += get_distance(route[city],route[city+1],distance_matrix)
    end
    distance += get_distance(route[1],route[length(route)],distance_matrix) # last city to city of origin 
    return distance
end



function get_data(xlsx_file_list)
    Pkg.add("XLSX")
    n = length(xlsx_file_list)
    objects = Vector(undef,n)
    sheets = Vector(undef,n)
    datas = Vector(undef,n)
    for i in eachindex(xlsx_file_list)
        objects[i] = XLSX.readxlsx(xlsx_file_list[i])
        sheets[i] = objects[i][XLSX.sheetnames(objects[i])[1]]
        datas[i] = sheets[i][:]
    end
    return datas    
end


#### initial population / sasiedztwo
function create_random_population(citycount,populationsize)
    population = [ sample(1:citycount, citycount, replace = false) for i in 1:populationsize]
    return population
end


#fitness weighted probability 
# Adds fitness function to population so we can choose best parents 
function find_potential_parents(population,distance_matrix)
    distances = [0.0 for i in 1:length(population)]
    for i in 1:length(population)
        distances[i] = get_route_distance(population[i],distance_matrix)
    end
    probabilities = [1/i for i in distances] #inverting values so the bigger the route the smaller the probability
    probabilities = [i - (2*(mean(probabilities))-findmax(probabilities)[1]) for i in probabilities] # scalling probabilites
    probabilities = [x > 0 ? x : 0  for x in probabilities]
    probabilities = [i/sum(probabilities) for i in probabilities] # calc probabilites
    df = DataFrame(Route = population,Len = distances,Prob = probabilities)
    return sort(df,["Len"])
end

#Selecting parents for breeding aka Mating Pool 
# df["Route"] self explanatory , Prob <=> Weights 

#Fitness proportionate selection 
function select_parents(potential_parents_df,k=2)
    return potential_parents_df[sample(axes(potential_parents_df,1),Weights(potential_parents_df[!,"Prob"]),k,replace=false),:]
end

#Tournament selection       
function select_parents_2(potential_parents_df,k=2)
    result = [[] for i in 1:k]
    for i in 1:k
        parents = potential_parents_df[sample(axes(potential_parents_df, 1), 2; replace = false, ordered = true), :]
        if parents[1,:]["Len"] < parents[2,:]["Len"]
            result[i] = parents[1,:]["Route"]
        else
            result[i] = parents[2,:]["Route"]
        end
    end
    return result
end

#function uniform_crossover(parent1,parent2)
#    n = length(parent1)
#    mask = bitrand(n)
#    offspring = [if mask[i] == true parent1[i] else parent2[i] end for i in 1:n]
#    return offspring
#end
#
function remove!(a, item)
    deleteat!(a, findall(x->x==item, a))
end

function OX(parent1,parent2)
    n = length(parent1)
    n_first_cut = Int(Random.rand(1:round(n/3)))
    n_second_cut = Int(Random.rand(1:round(n/4)))
    middle = n - n_first_cut - n_second_cut
    
    
    offspring1 = [0 for i in 1:n]
    offspring2 = copy(offspring1)
    to_sample_1 = [0 for i in 1:n_first_cut+n_second_cut]
    to_sample_2 = [0 for i in 1:n_first_cut+n_second_cut]
    
    for i in 1:(n_first_cut)
        if i<=n_first_cut
            to_sample_1[i] = parent1[i]
            to_sample_2[i] = parent2[i]
        end
    end
    
    for j in 1:n_second_cut
        to_sample_1[n_first_cut+j] = parent1[n_first_cut+ middle+j]
        to_sample_2[n_first_cut+j] = parent2[n_first_cut+ middle+j]
    end
    for i in 1:n
        if i <= n_first_cut
            offspring1[i] = sample(to_sample_1,1,replace=false)[1]
            offspring2[i] = sample(to_sample_2,1,replace=false)[1]
            remove!(to_sample_1,offspring1[i])
            remove!(to_sample_2,offspring2[i])
        elseif i >n_first_cut && i <=n-n_second_cut
            offspring1[i] = parent1[i]
            offspring2[i] = parent2[i]
        else
            offspring1[i] = sample(to_sample_1,1,replace=false)[1]
            offspring2[i] = sample(to_sample_2,1,replace=false)[1]
            remove!(to_sample_1,offspring1[i])
            remove!(to_sample_2,offspring2[i])
        end
    end
    return offspring1,offspring2
end

function MkX(parent1,parent2)
    n = length(parent1)

    unchanged_1 = sample(1:n,Int(round(n/4)),replace=false) #idx
    unchanged_2 = sample(1:n,Int(round(n/4)),replace=false)

    unchanged_1 = [1,2,3,4,5]

    offspring1 = [0 for i in 1:n]
    offspring2 = copy(offspring1)

    for i in unchanged_1
        offspring1[i] = parent1[i]
    end

    for j in unchanged_2
        offspring2[j] = parent2[j]
    end

    block1 = copy(unique(offspring1))
    block1 = remove!(block1,0)


    to_add1 = [i for i in parent2 if !(i in block1)]

    id1 = 1
    for i in 1:length(offspring1)
        if offspring1[i] == 0
            offspring1[i] = to_add1[id1]
            id1 +=1
        end
    end

    block2 = copy(unique(offspring2))
    block2 = remove!(block2,0)

    to_add2 = [i for i in parent1 if !(i in block2)]

    id2 = 1
    for i in 1:length(offspring2)
        if offspring2[i] == 0
            offspring2[i] = to_add2[id2]
            id2 +=1
        end
    end
    return offspring1,offspring2
end



function mutate(specimen,prob)
    test = rand(1:10)/10
    if test > prob
        n = length(specimen)
        idxs = Random.rand(1:n,5)
        idxs = unique(idxs)
        n1,n2 = idxs[1],idxs[2]
        tmp = specimen[n1]
        specimen[n1] = specimen[n2]
        specimen[n2] = tmp
    end
    return specimen
end

function mutate_pop(population,prob)
    n = length(population)
    for i in 1:n
        population[i] = copy(mutate(population[i],prob))
    end
    return population
end


function new_generation(mating_pool,number_of_offspring,ox = true,Fitness_proport_sel = true)
    new_gen = [[] for i in 1:number_of_offspring]
    if ox && Fitness_proport_sel
        for i in 1:Int(number_of_offspring/2)
            parents = select_parents(mating_pool)
            parent1,parent2 = parents[1,1],parents[2,1]
            offspring1,offspring2 = OX(parent1,parent2)
            new_gen[2*i-1] = offspring1
            new_gen[2*i] = offspring2
        end
    elseif ox && !Fitness_proport_sel
        for i in 1:Int(number_of_offspring/2)
            parents = select_parents_2(mating_pool)
            parent1,parent2 = parents[1],parents[2]
            offspring1,offspring2 = OX(parent1,parent2)
            new_gen[2*i-1] = offspring1
            new_gen[2*i] = offspring2
        end
    elseif !ox && Fitness_proport_sel
        for i in 1:Int(number_of_offspring/2)
            parents = select_parents(mating_pool)
            parent1,parent2 = parents[1,1],parents[2,1]
            offspring1,offspring2 = MkX(parent1,parent2)
            new_gen[2*i-1] = offspring1
            new_gen[2*i] = offspring2
        end
    else 
        for i in 1:Int(number_of_offspring/2)
            parents = select_parents_2(mating_pool)
            parent1,parent2 = parents[1],parents[2]
            offspring1,offspring2 = MkX(parent1,parent2)
            new_gen[2*i-1] = offspring1
            new_gen[2*i] = offspring2
        end
    end
    return new_gen
end


function GA(number_of_generations,distance_matrix,population_size,number_of_offsprings,mutation_prob =0.5,ox=true,fitness_prop=true)
    n_cities = length(distance_matrix[:,1])
    starting_population = create_random_population(n_cities,population_size)
    pop_fitness = find_potential_parents(starting_population,distance_matrix)
    mating_pool = copy(pop_fitness[1:10,:])

    for i in 1:number_of_generations
        new = new_generation(mating_pool,number_of_offsprings,ox,fitness_prop)
        new = mutate_pop(new,mutation_prob)
        pop_fitness = find_potential_parents(new,distance_matrix)
        mating_pool = pop_fitness[1:10,:]
    end

    return mating_pool[1,:]
end

function diagonal_to_zero(data)
    for i in 1:length(data[:,1])
        data[i,i] = 0
    end
    return data
end


### Main ###
#
#Random.seed!(1234)
#n_cities = length(all[1][:,1])
#distance_matrix = copy(all[1])
#

all = get_data(FILES)
all[4] = copy(diagonal_to_zero(all[4]))


function get_results(bool1,bool2,configuration)
    liczbapokolen = [200,300,400,500]
    liczbapotomkow = [20,30,40,50]
    prawdmutacji = [0.1,0.2,0.3,0.4]
    routes = [[] for i in 1:64]
    routes_len = [0 for i in 1:64]
    config = [" " for empty in 1:64]
    for m in 1:2
        counter = 1
        for pokolenie in liczbapokolen
            for potomkowie in liczbapotomkow
                for mutacje in prawdmutacji
                    result1 = GA(pokolenie,all[2],30,potomkowie,mutacje,bool1,bool2)
                    routes[counter] = result1[1]
                    routes_len[counter] = get_route_distance(result1[1],all[2])
                    config[counter] = string("Potomkowie:",potomkowie,"pokolenie:",pokolenie,"mutacje:",mutacje)
                    counter += 1
                    #print("\nPotomkowie: ",potomkowie,"pokolenie","\n","mutacje",mutacje)
                    #println(result1[1])
                    #println(get_route_distance(result1[1],all[2]))
                end
            end
        end
        if m==2
            break
        end
    end

    df = DataFrame(Route = routes,Leng = routes_len,Params = config)
    df = copy(sort(df,["Leng"]))
    name=configuration
    path= pwd()
    ext=".csv"
    PATH = string(path,name,ext)
    CSV.write(PATH,df)
end

#print(all[2])
#GA(200,all[2],30,20,0.2,true,false)


get_results(true,true,"TT")
get_results(false,true,"FT")
get_results(true,false,"TF")
get_results(false,false,"FF")#

