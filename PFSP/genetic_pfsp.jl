import Random
using StatsBase
using DataFrames
using Pkg
using XLSX
using CSV

EXCEL_F_NAME_2 = "Dane_PFSP_100_10.xlsx"   
EXCEL_F_NAME_3 = "Dane_PFSP_200_10.xlsx"   
EXCEL_F_NAME_4 = "Dane_PFSP_50_20.xlsx"    

FILES = [EXCEL_F_NAME_2,EXCEL_F_NAME_3,EXCEL_F_NAME_4]

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

function get_data_values(data)
    result = copy(data)
    for i in 1:length(data)
        m,n = length(result[i][:,1]),length(result[i][1,:])
        result[i] = result[i][2:m,2:n]
    end
    return result
end

function calculateTasks(data)

    n_machines = length(data[1,:])
    n_tasks = length(data[:,1])
    results = copy(data)
    for i in 1:n_tasks
        for j in 1:n_machines-1
            if i == 1
                if j == 1
                results[1,1] = data[1,1] 
                end
                results[1,j+1] = results[1,j] + data[1,j+1]
            else
                if j == 1      
                    results[i,1] = results[i-1,1] + data[i,1]
                end
                if results[i,j] < results[i-1,j+1]
                    results[i,j+1] = data[i,j+1] + results[i-1,j+1]
                else
                    results[i,j+1] = data[i,j+1] + results[i,j]
                end 
            end
        end
    end
    return results[n_tasks,n_machines]
end

#gets indexes for permutations of tasks
function create_random_population(populationsize,n_tasks,data)
    if populationsize > n_tasks
        print("Population size has to be smaller than number of tasks! (for them to be unique) ")
    end
    population = [[] for i in 1:populationsize]
    for i in 1:populationsize
        tmp_idx = sample(1:n_tasks, n_tasks, replace = false)   
        population[i] = tmp_idx 
    end
    
    return population
end

function find_potential_parents(population,datas) #data[1]
    task_sum = [0.0 for i in 1:length(population)]
    for i in 1:length(population)
        task_sum[i] = calculateTasks(datas[population[i],:])
    end
    probabilities = [1/i for i in task_sum] #inverting values so the bigger the task time the smaller the probability
    probabilities = [i - (2*(mean(probabilities))-findmax(probabilities)[1]) for i in probabilities] # scalling probabilites
    probabilities = [x > 0 ? x : 0  for x in probabilities]
    probabilities = [i/sum(probabilities) for i in probabilities] # calc probabilites
    df = DataFrame(Permutation = population,Len = task_sum,Prob = probabilities)
    return sort(df,["Len"])
end


function select_parents(potential_parents_df,k=2)
    return potential_parents_df[sample(axes(potential_parents_df,1),Weights(potential_parents_df[!,"Prob"]),k,replace=false),:]
end


#Tournament selection       
function select_parents_2(potential_parents_df,k=2)
    result = [[] for i in 1:k]
    for i in 1:k
        parents = potential_parents_df[sample(axes(potential_parents_df, 1), 2; replace = false, ordered = true), :]
        if parents[1,:]["Len"] < parents[2,:]["Len"]
            result[i] = parents[1,:]["Permutation"]
        else
            result[i] = parents[2,:]["Permutation"]
        end
    end
    return result
end


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

function find_unique_mask(a,b,idx) # idx = length of a mask

    n = length(a)
    mask1 = [0 for i in 1:idx]
    mask2 = copy(mask1)
    all = [0 for i in 1:2*idx]
    for i in 1:n-idx
        for j in 1:idx
            mask1[j] = a[i+j-1]
            mask2[j] = b[i+j-1]
            all[j] = a[i+j-1]
            all[j+idx] = b[i+j-1] 
        end
        cut = i
        if length(unique(all)) == 2*idx
            return mask1,mask2,cut-1
        end
    end
    if !(length(unique(all)) == 2*idx)
        return find_unique_mask(a,b,idx-1)
    end
end

function PMX(parent1,parent2)
    n = length(parent1)
    idxx = 5
    offspring1 = [0 for i in 1:n]
    offspring2 = copy(offspring1)
    mask1 = [0 for i in 1:idxx]
    mask2 = copy(mask1)
    #masks cannot contain duplicates :))
    mask1,mask2,idx = find_unique_mask(parent1,parent2,idxx)
    idxx = length(mask1)
    for i in 1:idxx
            offspring1[idx+i] = parent2[idx+i]
            offspring2[idx+i] = parent1[idx+i]
    end
    for i in 1:n
        if i <= idx || i > idx + idxx
            offspring1[i] = parent1[i]
            offspring2[i] = parent2[i]
            for j in 1:idxx
                if parent1[i] == mask2[j]
                    offspring1[i] = mask1[j]
                end

                if parent2[i] == mask1[j]
                    offspring2[i] = mask2[j]
                end

            end
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
        for i in 1:Int(round(number_of_offspring/2))
            parents = select_parents(mating_pool)
            parent1,parent2 = parents[1,1],parents[2,1]
            offspring1,offspring2 = OX(parent1,parent2) #switch OX to PMX for (true true)
            new_gen[2*i-1] = offspring1
            new_gen[2*i] = offspring2
        end
    elseif ox && !Fitness_proport_sel
        for i in 1:Int(round(number_of_offspring/2))
            parents = select_parents_2(mating_pool)
            parent1,parent2 = parents[1],parents[2]
            offspring1,offspring2 = OX(parent1,parent2) #switch OX to PMX for (true false)
            new_gen[2*i-1] = offspring1
            new_gen[2*i] = offspring2
        end
    elseif !ox && Fitness_proport_sel
        for i in 1:Int(round(number_of_offspring/2))
            parents = select_parents(mating_pool)
            parent1,parent2 = parents[1,1],parents[2,1]
            offspring1,offspring2 = MkX(parent1,parent2)
            new_gen[2*i-1] = offspring1
            new_gen[2*i] = offspring2
        end
    else 
        for i in 1:Int(round(number_of_offspring/2))
            parents = select_parents_2(mating_pool)
            parent1,parent2 = parents[1],parents[2]
            offspring1,offspring2 = MkX(parent1,parent2)
            new_gen[2*i-1] = offspring1
            new_gen[2*i] = offspring2
        end
    end
    return new_gen
end


function GA(number_of_generations,data_matrix,population_size,number_of_offsprings,mutation_prob =0.5,ox=true,fitness_prop=true)
    n_tasks = length(data_matrix[:,1])
    starting_population = create_random_population(population_size,n_tasks,data_matrix)
    pop_fitness = find_potential_parents(starting_population,data_matrix)
    mating_pool = copy(pop_fitness[1:10,:])

    for i in 1:number_of_generations
        new = new_generation(mating_pool,number_of_offsprings,ox,fitness_prop)
        new = mutate_pop(new,mutation_prob)
        pop_fitness = find_potential_parents(new,data_matrix)
        mating_pool = pop_fitness[1:10,:]
    end
    return mating_pool[1,:]
end


function CalculateTaskTime(dataFSPF)
    totalTasksTime = copy(dataFSPF)
    numberOfTasks =size(dataFSPF, 1) #n of rows
    numberOfMachines= size(dataFSPF, 2) #n of columns (machines)
    for i in 1:numberOfTasks
        for j in 2:numberOfMachines
            if(i ==1)
                if(j==1)
                totalTasksTime[i,j] = copy(dataFSPF[i,j])
                else 
                    totalTasksTime[i,j] = copy(dataFSPF[i,j]+totalTasksTime[i, j-1])
                end   
            else
                if(j==2)
                    totalTasksTime[i,j]=copy(totalTasksTime[i-1,j]+dataFSPF[i,j])
                 else
                    if(totalTasksTime[i,j-1]>totalTasksTime[i-1,j])
                        totalTasksTime[i,j] = copy(totalTasksTime[i,j-1]+dataFSPF[i,j])
                     else    
                        totalTasksTime[i,j] =copy(totalTasksTime[i-1,j]+dataFSPF[i,j])
                    end
                end                   
            end
        end
    end       
    return last(totalTasksTime)
end


all = get_data(FILES)
datas = get_data_values(all)

res = GA(100,datas[1],10,100,0.1,true,false) # bool1 crossover method , bool2 parent selection method #number of offsprings => 4th parametr must be even
print(res[1],res[2]," ",length(unique(res[1])))
